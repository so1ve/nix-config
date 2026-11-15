import json
import runpy
import sys
from pathlib import Path
from types import SimpleNamespace

from hermes_personal import eclass


def test_monitor_output_ignores_order_and_expiring_links(monkeypatch, capsys):
    reverse = False

    def courses():
        order = reversed((1, 2)) if reverse else (1, 2)
        return [{"id": str(course), "name": f"课{course}"} for course in order]

    def materials(course_id):
        order = reversed((11, 12)) if reverse else (11, 12)
        uploads = [
            {
                "id": upload,
                "name": f"{upload}.pdf",
                "link": f"https://example.invalid/file?expires={reverse}",
                "videos": [{"temporary": str(reverse)}],
            }
            for upload in order
        ]
        return [{"id": course_id, "title": "材料", "uploads": uploads}]

    class Client:
        def authenticate(self):
            return True

        def courses(self):
            return [{**course, "term": "2026-2027-1"} for course in courses()]

        def course(self, course_id):
            order = reversed((21, 22)) if reverse else (21, 22)
            return {
                "id": course_id,
                "replays": [{"sub_id": replay, "title": f"课堂 {replay}"} for replay in order],
            }

    script = Path(__file__).resolve().parents[1] / "scripts/course-check.py"
    monkeypatch.setattr(sys, "path", list(sys.path))
    monkeypatch.setitem(sys.modules, "client", SimpleNamespace(Yanhekt=Client))
    monkeypatch.setattr(eclass, "courses", courses)
    monkeypatch.setattr(eclass, "materials", materials)

    runpy.run_path(str(script))
    baseline = capsys.readouterr().out
    reverse = True
    runpy.run_path(str(script))
    assert capsys.readouterr().out == baseline
    snapshot = json.loads(baseline)
    assert snapshot["materials"][0]["activity"]["uploads"][0] == {"id": 11, "name": "11.pdf"}
    assert snapshot["replays"][0]["replays"][0] == {"sub_id": 21, "title": "课堂 21"}
