local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

return {
  s("def", fmt([[
def {}({}):
    {}
]], {
    i(1),
    i(2),
    i(0, "pass"),
  })),

  s("meth", fmt([[
def {}(self, {}):
    {}
]], {
    i(1),
    i(2),
    i(0, "pass"),
  })),

  s("adef", fmt([[
async def {}({}):
    {}
]], {
    i(1),
    i(2),
    i(0, "pass"),
  })),

  s("ameth", fmt([[
async def {}(self, {}):
    {}
]], {
    i(1),
    i(2),
    i(0, "pass"),
  })),

  s("init", fmt([[
def __init__(self, {}):
    {}
]], {
    i(1),
    i(0, "pass"),
  })),

  s("class", fmt([[
class {}({}):
    def __init__(self, {}):
        {}
]], {
    i(1),
    i(2, "object"),
    i(3),
    i(0, "pass"),
  })),

  s("dc", fmt([[
@dataclass
class {}:
    {}
]], {
    i(1),
    i(0, "pass"),
  })),

  s("prop", fmt([[
@property
def {}(self):
    {}
]], {
    i(1),
    i(0, "pass"),
  })),

  s("setter", fmt([[
@{}.setter
def {}(self, value):
    {}
]], {
    i(1),
    rep(1),
    i(0, "pass"),
  })),

  s("cls", fmt([[
@classmethod
def {}(cls, {}):
    {}
]], {
    i(1),
    i(2),
    i(0, "pass"),
  })),

  s("static", fmt([[
@staticmethod
def {}({}):
    {}
]], {
    i(1),
    i(2),
    i(0, "pass"),
  })),

  s("if", fmt([[
if {}:
    {}
]], {
    i(1),
    i(0, "pass"),
  })),

  s("elif", fmt([[
elif {}:
    {}
]], {
    i(1),
    i(0, "pass"),
  })),

  s("else", fmt([[
else:
    {}
]], {
    i(0, "pass"),
  })),

  s("for", fmt([[
for {} in {}:
    {}
]], {
    i(1, "item"),
    i(2, "iterable"),
    i(0, "pass"),
  })),

  s("afor", fmt([[
async for {} in {}:
    {}
]], {
    i(1, "item"),
    i(2, "aiterable"),
    i(0, "pass"),
  })),

  s("while", fmt([[
while {}:
    {}
]], {
    i(1),
    i(0, "pass"),
  })),

  s("with", fmt([[
with {} as {}:
    {}
]], {
    i(1),
    i(2, "value"),
    i(0, "pass"),
  })),

  s("awith", fmt([[
async with {} as {}:
    {}
]], {
    i(1),
    i(2, "value"),
    i(0, "pass"),
  })),

  s("try", fmt([[
try:
    {}
except {} as {}:
    {}
]], {
    i(1),
    i(2, "Exception"),
    i(3, "exc"),
    i(0, "pass"),
  })),

  s("tryf", fmt([[
try:
    {}
except {} as {}:
    {}
finally:
    {}
]], {
    i(1),
    i(2, "Exception"),
    i(3, "exc"),
    i(4, "pass"),
    i(0, "pass"),
  })),

  s("match", fmt([[
match {}:
    case {}:
        {}
]], {
    i(1),
    i(2),
    i(0, "pass"),
  })),

  s("case", fmt([[
case {}:
    {}
]], {
    i(1),
    i(0, "pass"),
  })),

  s("guard", fmt([[
if {}:
    {}
else:
    {}
]], {
    i(1),
    i(2, "pass"),
    i(0, "pass"),
  })),

  s("listc", fmt([[{} for {} in {}]], {
    i(1, "expr"),
    i(2, "item"),
    i(0, "iterable"),
  })),

  s("dictc", fmt([[{{{}: {} for {} in {}}}]], {
    i(1, "key"),
    i(2, "value"),
    i(3, "item"),
    i(0, "iterable"),
  })),

  s("log", fmt([[logger.{}("{}=%r", {})]], {
    i(1, "info"),
    i(2, "value"),
    i(0, "value"),
  })),

  s("ret", fmt([[return {}]], {
    i(0),
  })),

  s("yield", fmt([[yield {}]], {
    i(0),
  })),

  s("raise", fmt([[raise {}]], {
    i(0, "RuntimeError()"),
  })),

  s("imp", fmt([[import {}]], {
    i(0),
  })),

  s("from", fmt([[from {} import {}]], {
    i(1),
    i(0),
  })),

  s("fstr", fmt([[f"{}"]], {
    i(0),
  })),

  s("ctx", fmt([[
@contextmanager
def {}({}):
    {}
    try:
        yield {}
    finally:
        {}
]], {
    i(1),
    i(2),
    i(3, "resource = None"),
    i(4, "resource"),
    i(0, "pass"),
  })),

  s("test", fmt([[
def test_{}():
    {}
]], {
    i(1),
    i(0, "assert False"),
  })),

  s("fixture", fmt([[
@pytest.fixture
def {}():
    {}
]], {
    i(1),
    i(0, "yield"),
  })),

  s("parametrize", fmt([[
@pytest.mark.parametrize(("{}"), [
    ({})
])
def test_{}({}):
    {}
]], {
    i(1, "value"),
    i(2),
    i(3),
    i(4, "value"),
    i(0, "assert False"),
  })),

  s("pytestraises", fmt([[
with pytest.raises({}):
    {}
]], {
    i(1, "ValueError"),
    i(0),
  })),

  s("pytestmark", fmt([[
pytestmark = pytest.mark.{}
]], {
    i(0, "asyncio"),
  })),

  s("fixturemod", fmt([[
@pytest.fixture(scope="module")
def {}():
    {}
]], {
    i(1),
    i(0, "yield"),
  })),

  s("fixtureasync", fmt([[
@pytest.fixture
async def {}():
    {}
]], {
    i(1),
    i(0, "yield"),
  })),

  s("lsget", fmt([[
@get("{}")
async def {}() -> {}:
    {}
]], {
    i(1, "/"),
    i(2),
    i(3, "dict[str, str]"),
    i(0, [[return {"status": "ok"}]]),
  })),

  s("lspost", fmt([[
@post("{}")
async def {}(data: {}) -> {}:
    {}
]], {
    i(1, "/"),
    i(2),
    i(3, "Payload"),
    i(4, "Response"),
    i(0, "return data"),
  })),

  s("lsput", fmt([[
@put("{}")
async def {}({}: {}, data: {}) -> {}:
    {}
]], {
    i(1, "/{id:int}"),
    i(2),
    i(3, "item_id"),
    i(4, "int"),
    i(5, "Payload"),
    i(6, "Response"),
    i(0, "return data"),
  })),

  s("lsdelete", fmt([[
@delete("{}")
async def {}({}: {}) -> None:
    {}
]], {
    i(1, "/{id:int}"),
    i(2),
    i(3, "item_id"),
    i(4, "int"),
    i(0, "return None"),
  })),

  s("lsexc", fmt([[
raise HTTPException(status_code={}, detail="{}")
]], {
    i(1, "404"),
    i(0, "Not found"),
  })),

  s("lsctrl", fmt([[
class {}Controller(Controller):
    path = "{}"

    @get("/")
    async def list_{}(self) -> {}:
        {}
]], {
    i(1),
    i(2, "/items"),
    i(3, "items"),
    i(4, "list[dict[str, str]]"),
    i(0, "return []"),
  })),

  s("lsdto", fmt([[
class {}DTO(DTO[{}]):
    config = DTOConfig()
]], {
    i(1),
    i(0, "Model"),
  })),

  s("pmodel", fmt([[
class {}(BaseModel):
    {}
]], {
    i(1),
    i(0, "name: str"),
  })),

  s("pfield", fmt([[{}: {} = Field(default={}, description="{}")]], {
    i(1, "name"),
    i(2, "str"),
    i(3, "..."),
    i(0),
  })),

  s("fval", fmt([[
@field_validator("{}")
@classmethod
def {}(cls, value: {}) -> {}:
    {}
    return value
]], {
    i(1, "field_name"),
    i(2, "validate_field_name"),
    i(3, "str"),
    rep(3),
    i(0, "if not value:\n        raise ValueError(\"value is required\")"),
  })),

  s("mval", fmt([[
@model_validator(mode="{}")
def {}(self):
    {}
    return self
]], {
    i(1, "after"),
    i(2, "validate_model"),
    i(0, "pass"),
  })),

  s("pconfig", fmt([[model_config = ConfigDict({}={})]], {
    i(1, "from_attributes"),
    i(0, "True"),
  })),

  s("pdump", fmt([[{}.model_dump()]], {
    i(0, "model"),
  })),

  s("djshell", fmt([[
if __name__ == "__main__":
    import django
    django.setup()
    {}
]], {
    i(0, "pass"),
  })),

  s("djmodel", fmt([[
class {}(models.Model):
    {}

    def __str__(self) -> str:
        return str(self.{})
]], {
    i(1),
    i(2, "name = models.CharField(max_length=255)"),
    i(0, "name"),
  })),

  s("djadmin", fmt([[
@admin.register({})
class {}Admin(admin.ModelAdmin):
    list_display = ({})
    search_fields = ({})
]], {
    i(1, "Model"),
    i(2, "Model"),
    i(3, [["id", "name"]]),
    i(0, [["name"]]),
  })),

  s("djview", fmt([[
def {}(request: HttpRequest) -> HttpResponse:
    {}
]], {
    i(1),
    i(0, [[return render(request, "template.html", {})]]),
  })),

  s("djcbv", fmt([[
class {}View(View):
    def get(self, request: HttpRequest, *args, **kwargs) -> HttpResponse:
        {}
]], {
    i(1),
    i(0, [[return render(request, "template.html", {})]]),
  })),

  s("djurl", fmt([[path("{}", {}, name="{}")]], {
    i(1),
    i(2),
    i(0),
  })),

  s("djform", fmt([[
class {}Form(forms.Form):
    {}
]], {
    i(1),
    i(0, "name = forms.CharField(max_length=255)"),
  })),

  s("djmform", fmt([[
class {}Form(forms.ModelForm):
    class Meta:
        model = {}
        fields = [{}]
]], {
    i(1),
    i(2, "Model"),
    i(0, [["__all__"]]),
  })),

  s("djtest", fmt([[
class {}Test(TestCase):
    def test_{}(self) -> None:
        {}
]], {
    i(1),
    i(2),
    i(0, "self.assertTrue(True)"),
  })),

  s("djqset", fmt([[{}.objects.filter({}={})]], {
    i(1, "Model"),
    i(2, "field"),
    i(0, "value"),
  })),

  s("assert", fmt([[assert {}]], {
    i(0),
  })),

  s("main", fmt([[
def main():
    {}


if __name__ == "__main__":
    main()
]], {
    i(0, "pass"),
  })),
}
