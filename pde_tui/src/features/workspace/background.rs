// All subprocess work belongs to this worker. Navigation only reads the cache
// and queues a request; the worker keeps the latest queued selection.
const DETAIL_CACHE_TTL: Duration = Duration::from_secs(5);

#[derive(Debug)]
struct CachedDetail {
    detail: ProjectInspect,
    loaded_at: Instant,
}

#[derive(Debug)]
struct LoadRequest {
    id: u64,
    generation: u64,
    slug: Option<String>,
    refresh_sessions: bool,
}

#[derive(Debug)]
struct LoadResult {
    id: u64,
    generation: u64,
    slug: Option<String>,
    detail: Result<Option<ProjectInspect>>,
    sessions: Option<Vec<SessionRow>>,
}

#[derive(Debug)]
struct BackgroundLoader {
    requests: Sender<LoadRequest>,
    results: Receiver<LoadResult>,
    requested: u64,
    completed: u64,
}

impl BackgroundLoader {
    fn start(root: PathBuf) -> Result<Self> {
        Self::start_with(move |request| {
            let detail = request
                .slug
                .as_deref()
                .map(|slug| inspect_project(&root, slug))
                .transpose();
            // The inspect helper already queried both multiplexers.
            let sessions = detail
                .as_ref()
                .ok()
                .and_then(|detail| detail.as_ref())
                .and_then(|detail| detail.sessions.as_ref())
                .map(inspect_sessions)
                .or_else(|| request.refresh_sessions.then(load_global_sessions));
            LoadResult {
                id: request.id,
                generation: request.generation,
                slug: request.slug,
                detail,
                sessions,
            }
        })
    }

    fn start_with(load: impl Fn(LoadRequest) -> LoadResult + Send + 'static) -> Result<Self> {
        let (requests, incoming) = mpsc::channel();
        let (completed, results) = mpsc::channel();
        thread::Builder::new()
            .name("workspace-loader".into())
            .spawn(move || {
                while let Ok(request) = incoming.recv() {
                    let request = latest_request(request, incoming.try_iter());
                    if completed.send(load(request)).is_err() {
                        break;
                    }
                }
            })
            .context("failed to start workspace loader")?;
        Ok(Self {
            requests,
            results,
            requested: 0,
            completed: 0,
        })
    }

    fn request(&mut self, mut request: LoadRequest) {
        self.requested = self.requested.wrapping_add(1);
        request.id = self.requested;
        if self.requests.send(request).is_err() {
            self.completed = self.requested;
        }
    }

    #[cfg(test)]
    fn disconnected() -> Self {
        let (requests, _) = mpsc::channel();
        let (_, results) = mpsc::channel();
        Self {
            requests,
            results,
            requested: 0,
            completed: 0,
        }
    }
}

fn latest_request(
    mut request: LoadRequest,
    queued: impl Iterator<Item = LoadRequest>,
) -> LoadRequest {
    for mut next in queued {
        if request.generation == next.generation {
            next.refresh_sessions |= request.refresh_sessions;
        }
        request = next;
    }
    request
}

fn inspect_sessions(sessions: &InspectSessions) -> Vec<SessionRow> {
    [
        (SessionBackend::Tmux, &sessions.tmux),
        (SessionBackend::Zellij, &sessions.zellij),
    ]
    .into_iter()
    .flat_map(|(backend, names)| {
        names.iter().map(move |session| SessionRow {
            backend,
            label: session.clone(),
            session: session.clone(),
        })
    })
    .collect()
}

impl WorkspaceState {
    fn refresh_detail(&mut self, refresh_sessions: bool) {
        let slug = self.selected_project().map(|project| project.slug.clone());
        let cached = slug.as_ref().and_then(|slug| self.detail_cache.get(slug));
        let fresh = cached.is_some_and(|entry| entry.loaded_at.elapsed() < DETAIL_CACHE_TTL);
        let detail = cached.map(|entry| entry.detail.clone());
        self.detail_loading = slug.is_some() && !fresh;
        self.detail_error = None;
        self.apply_detail(detail);
        // A cache hit also replaces queued work for a project we left behind.
        self.loader.request(LoadRequest {
            id: 0,
            generation: self.generation,
            slug: slug.filter(|_| !fresh),
            refresh_sessions,
        });
    }

    pub fn poll_background(&mut self) -> Option<String> {
        let mut message = None;
        while let Ok(result) = self.loader.results.try_recv() {
            self.loader.completed = result.id;
            if let Some(error) = self.accept_background(result) {
                message = Some(error);
            }
        }
        message
    }

    pub fn background_pending(&self) -> bool {
        self.loader.requested != self.loader.completed
    }

    fn accept_background(&mut self, result: LoadResult) -> Option<String> {
        if result.generation != self.generation {
            return None;
        }
        if let Some(sessions) = result.sessions {
            self.global_sessions = sessions;
            selection::clamp_selection(&mut self.global_session_list, self.global_sessions.len());
        }
        let slug = result.slug?;
        let selected = self
            .selected_project()
            .is_some_and(|project| project.slug == slug);
        if selected {
            self.detail_loading = false;
        }
        match result.detail {
            Ok(Some(detail)) => {
                if selected {
                    self.detail_error = None;
                    self.apply_detail(Some(detail.clone()));
                }
                self.detail_cache.insert(
                    slug,
                    CachedDetail {
                        detail,
                        loaded_at: Instant::now(),
                    },
                );
                None
            }
            Err(error) if selected => {
                let message = error.to_string();
                self.detail_error = Some(message.clone());
                Some(message)
            }
            _ => None,
        }
    }

    fn detail_status(&self) -> Option<&str> {
        if self.detail_loading {
            Some("Loading…")
        } else {
            self.detail_error.as_deref()
        }
    }
}
