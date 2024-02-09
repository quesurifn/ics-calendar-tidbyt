load("render.star", "render")
load("http.star", "http")
load("time.star", "time")
load("schema.star", "schema")
load("encoding/base64.star", "base64")
load("encoding/json.star", "json")

FRAME_DELAY = 500
LAMBDA_URL = "https://xmd10xd284.execute-api.us-east-1.amazonaws.com/ics-next-event"
CALENDAR_ICON = base64.decode("iVBORw0KGgoAAAANSUhEUgAAAAkAAAALCAYAAACtWacbAAAAAXNSR0IArs4c6QAAAE9JREFUKFNjZGBgYJgzZ87/lJQURlw0I0xRYEMHw/qGCgZ0GqSZ8a2Myv8aX1eGls27GXDRYEUg0/ABxv///xOn6OjRowzW1tYMuOghaxIAD/ltSOskB+YAAAAASUVORK5CYII=")
DEFAULT_ICS_URL = "https://www.phpclasses.org/browse/download/1/file/63438/name/example.ics"
DEFAULT_TIMEZONE = "America/Chicago"
def main(config):
    ics_url = config.str("ics_url", DEFAULT_ICS_URL)
    if(ics_url == None):
        fail("ICS_URL not set in config")

    usersTz = config.str("tz", "America/Chicago")
    if(usersTz == None):
        fail("TZ not set in config")

    now = time.now().in_location(usersTz)
    ics = http.post(
        url=LAMBDA_URL,
        json_body={"icsUrl": ics_url, "tz": usersTz},
    )
    if(ics.status_code != 200):
        fail("Failed to fetch ICS file")

    event = ics.json()["data"]
    if not event:
        # no events in the calendar
        return build_calendar_frame(now, usersTz)
    if event['detail']['thirtyMinuteWarning']:
        return build_calendar_frame(now, usersTz, event)
    elif event['detail']['tenMinuteWarning']:
        return build_event_frame(now, usersTz, event)
    elif event['detail']['fiveMinuteWarning']:
        return build_event_frame(now, usersTz, event)
    elif event['detail']['oneMinuteWarning']:
        return build_event_frame(now, usersTz, event)
    elif event['detail']['inProgress']:
        return build_event_frame(now, usersTz, event)
    elif event['detail']['isToday']:
        return build_calendar_frame(now, usersTz)
    else:
        return build_calendar_frame(now, usersTz)

def build_calendar_frame(now, usersTz, event = None):
    month = now.format("Jan")
    day = now.format("Monday")
    eventStart = None
    if event:
        eventStart = time.parse(event['start']).in_location(usersTz)


    # top half displays the calendar icon and date
    top = [
       render.Row(
            cross_align = "center",
            expanded = True,
            children = [
                render.Image(src = CALENDAR_ICON, width = 9, height = 11),
                render.Box(width = 2, height = 1),
                render.Text(
                    month.upper(),
                    color = "#ff83f3",
                    offset = -1,
                ),
                render.Box(width = 1, height = 1),
                render.Text(
                    str(now.day),
                    color = "#ff83f3",
                    offset = -1,
                ),
            ],
        ),
        render.Box(height = 2),
    ]

    # bottom half displays the upcoming event, if there is one.
    # otherwise it just shows the time.
    if event:
        bottom = [
            render.Marquee(
                width = 64,
                child = render.Text(
                    event['name'].upper(),
                ),
            ),
            render.Text(
                eventStart.format("at 3:04 PM"),
                color = "#fff500",
            ),
        ]
    else:
        bottom = [
            render.Column(
                expanded = True,
                main_align = "end",
                children = [
                    render.WrappedText(
                        "NO MORE MEETINGS :-)",
                        color = "#fff500",
                        height = 16,
                    ),
                ],
            ),
        ]

    return render.Root(
        delay = FRAME_DELAY,
        child = render.Box(
            padding = 2,
            color = "#111",
            child = render.Column(
                expanded = True,
                children = top + bottom,
            ),
        ),
    )

def build_event_frame(now, usersTz, event):
    minutes_to_start = event['detail']['minutesUntilStart']
    minutes_to_end = event['detail']['minutesUntilEnd']
    hours_to_end = event['detail']['hoursToEnd']

    color = "#ff78e9"
    fiveMinuteWarning = event['detail']['fiveMinuteWarning']
    oneMinuteWarning = event['detail']['oneMinuteWarning']
    if fiveMinuteWarning:
        color = "#ff5000"
    if oneMinuteWarning:
        color = "#9000ff"


    if minutes_to_start >= 1:
        tagline = ("in %d" % minutes_to_start, "min")
    elif hours_to_end >= 99:
        tagline = ("", "now")
    elif minutes_to_end >= 99:
        tagline = ("Ends in %d" % hours_to_end, "h")
    elif minutes_to_end > 1:
        tagline = ("Ends in %d" % minutes_to_end, "min")
    else:
        tagline = ("", "almost done")

    return render.Root(
        child = render.Box(
            padding = 2,
            child = render.Column(
                main_align = "start",
                cross_align = "start",
                expanded = True,
                children = [
                    render.WrappedText(
                        event['name'].upper(),
                        height = 17,
                    ),
                    render.Box(
                        color = color,
                        height = 1,
                    ),
                    render.Box(height = 3),
                    render.Row(
                        main_align = "end",
                        expanded = True,
                        children = [
                            render.Text(
                                tagline[0],
                                color = "#fff500",
                            ),
                            render.Box(height = 1, width = 1),
                            render.Text(
                                tagline[1],
                                color = "#fff500",
                            ),
                        ],
                    ),
                ],
            ),
        ),
    )


def get_schema():
    return schema.Schema(
            version = "1",
            fields = [
                schema.Text(
                    id = "ics_url",
                    name = "iCalendar URL",
                    desc = "The URL of the iCalendar file",
                    icon = "calendar",
                    default = DEFAULT_ICS_URL,
                ),
                schema.Text(
                    id = "tz",
                    name = "Default Timezone",
                    desc = "e.g. America/Chicago",
                    icon = "clock",
                    default = DEFAULT_TIMEZONE,
                ),
            ],
        )
