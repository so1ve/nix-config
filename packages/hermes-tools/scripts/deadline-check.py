import logging
from datetime import datetime

from hermes_personal import eclass, lexue, reminders, yanhekt

logger = logging.getLogger(__name__)
events, errors = [], []
for source in (lexue, eclass, yanhekt):
    try:
        events.extend(source.calendar())
    except (OSError, RuntimeError, ValueError) as error:
        errors.append(error)
        logger.warning("%s 截止时间读取失败：%s", source.__name__, error)
if errors and not events:
    raise errors[0]
print(reminders.message(events, datetime.now(reminders.SHANGHAI)))
