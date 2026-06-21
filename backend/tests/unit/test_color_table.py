from brickfinder.colors.table import ColorTable, load_default


def test_lookup_canonical_name():
    t = ColorTable.from_dict({"colors": [{"id": 4, "name": "Red", "aliases": ["red"]}]})
    assert t.lookup("Red") == 4
    assert t.lookup("red") == 4
    assert t.lookup("RED") == 4


def test_lookup_alias():
    t = ColorTable.from_dict(
        {
            "colors": [
                {
                    "id": 71,
                    "name": "Light Bluish Gray",
                    "aliases": ["light bluish gray", "lightbluishgray"],
                }
            ]
        }
    )
    assert t.lookup("lightbluishgray") == 71
    assert t.lookup("Light Bluish Gray") == 71


def test_lookup_unknown_returns_minus_one():
    t = ColorTable.from_dict({"colors": []})
    assert t.lookup("Magenta") == -1


def test_load_default_includes_red():
    t = load_default()
    assert t.lookup("Red") == 4
