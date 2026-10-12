from pathlib import Path
import pytest
from configure import render


def test_private_encrypted_policy():
    example = {"database": {}, "bridge": {"relay": {}}, "encryption": {}, "appservice": {"bot": {}}}
    credentials = {"bridge": {"permissions": {"@fixture:example.test": "admin"}}, "network": {"account_id": "bf-fixture"}, "appservice": {"as_token": "fixture-only"}}
    result = render(example, credentials, Path("/home/fixture"))
    assert result["appservice"]["as_token"] == "fixture-only"
    assert result["encryption"] == {"allow": True, "default": True, "require": True}
    assert result["bridge"]["relay"]["enabled"] is False
    assert result["network"]["owner"] == "@fixture:example.test"
    assert not example["database"]
    credentials["bridge"]["permissions"]["*"] = "admin"
    with pytest.raises(ValueError):
        render(example, credentials, Path("/home/fixture"))
