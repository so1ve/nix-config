"""Snapshot enrolled course materials and ready replays for a native monitor."""

import json
import sys

from hermes_personal import config, eclass

sys.path.insert(0, str(config.home() / "skills/yanhekit/scripts"))
from client import Yanhekt

materials = []
for course in eclass.courses():
    for activity in eclass.materials(str(course["id"])):
        materials.append({"course": course, "activity": activity})

client = Yanhekt()
if not client.authenticate():
    raise RuntimeError("延河录播会话无效，请通过校园登录工具重新认证")
courses = client.courses()
latest_term = max((course["term"] for course in courses), default="")
replays = [client.course(course["id"]) for course in courses if course["term"] == latest_term]

# Signed links expire and change independently of the material itself.
for item in materials:
    uploads = item["activity"]["uploads"]
    uploads.sort(key=lambda upload: str(upload["id"]))
    for upload in uploads:
        upload.pop("link", None)
        upload.pop("videos", None)
materials.sort(key=lambda item: (item["course"]["id"], item["activity"]["id"]))
for course in replays:
    course["replays"].sort(key=lambda replay: str(replay["sub_id"]))
replays.sort(key=lambda course: str(course["id"]))
print(json.dumps({"materials": materials, "replays": replays}, ensure_ascii=False, sort_keys=True))
