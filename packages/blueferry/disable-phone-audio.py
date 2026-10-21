"""Add BlueZ device.disabled support to the installed WirePlumber monitor."""
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
anchor = "    -- create the device\n    device = SpaDevice(factory, properties)"
if source.count(anchor) != 1:
    raise SystemExit("WirePlumber BlueZ monitor changed; review the device.disabled patch")
replacement = """    -- Respect phone audio exclusions before creating any profiles or nodes.
    if cutils.parseBool(properties["device.disabled"]) then
      return
    end

""" + anchor
Path(sys.argv[2]).write_text(source.replace(anchor, replacement))
