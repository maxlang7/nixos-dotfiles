#!/usr/bin/env python3.12
import aw_query
from datetime import datetime, timedelta, timezone
from aw_client import ActivityWatchClient

client = ActivityWatchClient("test-client", testing=False)

now = datetime.utcnow()
#start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=timezone.utc)
#end_of_today = now.replace(hour=23, minute=59, second=59, microsecond=0, tzinfo=timezone.utc)
start_of_today = datetime(1970, 1, 1, tzinfo=timezone.utc)
end_of_today = datetime(2100, 1, 1, tzinfo=timezone.utc)

time_periods = [(start_of_today, end_of_today)]
query = "RETURN 0"

events = client.query(query, time_periods)

# sum the time spent on each app
time_spent = dict()
print(events[0])
for event in events:
    app = event.data["app"]
    if app in time_spent:
        time_spent[app] += event.duration
    else:
        time_spent[app] = event.duration

print(time_spent)