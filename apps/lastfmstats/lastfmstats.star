"""
Applet: LastFM Stats
Summary: Displays stats from Last.fm
Description: Displays the top artist and track for a last.fm user over a given period of time.
Author: skinner452
"""

load("animation.star", "animation")
load("http.star", "http")
load("humanize.star", "humanize")
load("render.star", "render")
load("schema.star", "schema")

# Converts period values to display strings
PERIOD_STRINGS = {
    "overall": "Overall",
    "7day": "Past week",
    "1month": "Past month",
    "3month": "Past 3 months",
    "6month": "Past 6 months",
    "12month": "Past year",
}

# Demo mode data
DEMO_ARTIST = {
    "name": "The Killers",
    "artwork": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/51/The_Killers_%40_Bonnaroo_2018.jpg/1200px-The_Killers_%40_Bonnaroo_2018.jpg",
    "plays": "123",
}
DEMO_TRACK = {
    "name": "Mr. Brightside",
    "artwork": "https://upload.wikimedia.org/wikipedia/en/1/17/The_Killers_-_Hot_Fuss.png",
    "plays": "10",
}

def main(config):
    """Entry point to the TidByt app

    Args:
      config: User configuration for the app

    Returns:
      A render of the app or error
    """

    username = config.str("username")
    period = config.str("period")
    apikey = config.str("apikey")
    if not username or not period or not apikey:
        top_artist = DEMO_ARTIST
        top_track = DEMO_TRACK
        period = "12month"
    else:
        top_artist = get_top_artist(username, period, apikey)
        if top_artist == None:
            return render_error("Failed to get top artist")
        top_track = get_top_track(username, period, apikey)
        if top_track == None:
            return render_error("Failed to get top track")

    return render.Root(
        child = render.Sequence(
            children = [
                sequence_frame(
                    render_slide("Top Artist", top_artist, period),
                    150,
                ),
                sequence_frame(
                    render_slide("Top Track", top_track, period),
                    150,
                ),
            ],
        ),
    )

def get_schema():
    """Get schema to be used when configuring the app

    Returns:
      A Schema object of config options
    """

    period_options = [
        schema.Option(
            display = "Overall",
            value = "overall",
        ),
        schema.Option(
            display = "1 Week",
            value = "7day",
        ),
        schema.Option(
            display = "1 Month",
            value = "1month",
        ),
        schema.Option(
            display = "3 Months",
            value = "3month",
        ),
        schema.Option(
            display = "6 Months",
            value = "6month",
        ),
        schema.Option(
            display = "1 Year",
            value = "12month",
        ),
    ]

    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "username",
                name = "Username",
                desc = "Last.fm Username",
                icon = "user",
            ),
            schema.Dropdown(
                id = "period",
                name = "Period",
                desc = "Period of time for stats",
                icon = "clock",
                default = period_options[0].value,
                options = period_options,
            ),
            schema.Text(
                id = "apikey",
                name = "Last.fm API Key",
                desc = "API Key created from last.fm/api",
                icon = "key",
            ),
        ],
    )

def render_error(error):
    """Renders any given string as an error screen

    Args:
      error: Error string to be displayed

    Returns:
      A render of the error screen
    """

    return render.Root(
        child = render.Box(
            child = render.WrappedText(error, font = "tom-thumb"),
        ),
    )

def render_slide(title, data, period):
    """Renders an individual slide for the app

    Args:
      title: String that describes data that is being shown
      data: Object with keys "name", "artwork", and "plays"
      period: Period of time this data was over

    Returns:
      A render of the slide with the provided data
    """

    artwork = http.get(data["artwork"]).body()

    return render.Box(
        padding = 1,
        child = render.Column(
            expanded = True,
            main_align = "space_around",
            children = [
                render.Row(
                    expanded = True,
                    main_align = "center",
                    children = [
                        render.Text(PERIOD_STRINGS[period], font = "tom-thumb", color = "#c3000d"),
                    ],
                ),
                render.Row(
                    expanded = True,
                    main_align = "space_between",
                    children = [
                        render.Image(src = artwork, width = 21, height = 21),
                        render.Column(
                            children = [
                                render.Text(title, font = "tom-thumb", height = 7),
                                render.Marquee(
                                    width = 40,
                                    child = render.Text(data["name"], font = "tom-thumb", height = 7),
                                ),
                                render.Text(data["plays"] + " plays", font = "tom-thumb", height = 7),
                            ],
                        ),
                    ],
                ),
            ],
        ),
    )

def sequence_frame(content, duration):
    """Helper function to wrap content in an animation for a given duration

    Args:
      content: Render to be displayed
      duration: Time to display the frame (in number of frames)

    Returns:
      An animation.Transformation object that shows the content for a duration
    """

    return animation.Transformation(
        duration = duration,
        keyframes = [],
        child = content,
    )

def get_top_artist(username, period, apikey):
    """Queries last.fm for the top artist of a user over a period of time

    Args:
      username: Username to lookup
      period: Period to search
      apikey: Last.fm API key

    Returns:
      An object with artist or None if error
    """

    data = query(apikey, "user.gettopartists", "username=" + username + "&period=" + period + "&limit=1")
    if data == None:
        return None

    if nested_keys_exist(data, ["topartists", "artist", 0]) == False:
        return None

    top_artist = data["topartists"]["artist"][0]
    if "name" not in top_artist or "playcount" not in top_artist:
        return None

    # last.fm artist artwork only displays a white star
    # We can attempt to pull artist artwork from spotify
    # If it fails, we can just fall back to the last.fm artwork
    artwork = get_artwork_from_spotify(top_artist["name"])

    if artwork == None:
        # Fallback to the last.fm artwork
        if nested_keys_exist(top_artist, ["image", 0, "#text"]) == False:
            return None
        artwork = top_artist["image"][0]["#text"]

    return {
        "plays": top_artist["playcount"],
        "name": top_artist["name"],
        "artwork": artwork,
    }

def get_top_track(username, period, apikey):
    """Queries last.fm for the top artist of a user over a period of time

    Args:
      username: Username to lookup
      period: Period to search
      apikey: Last.fm API key

    Returns:
      An object with track or error data
    """

    data = query(apikey, "user.gettoptracks", "username=" + username + "&period=" + period + "&limit=1")
    if data == None:
        return None

    if nested_keys_exist(data, ["toptracks", "track", 0]) == False:
        return None
    top_track = data["toptracks"]["track"][0]

    if "name" not in top_track or "playcount" not in top_track:
        return None
    track_name = humanize.url_encode(top_track["name"])

    if nested_keys_exist(top_track, ["artist", "name"]) == False:
        return None
    artist_name = humanize.url_encode(top_track["artist"]["name"])

    # Query the track info to get the album artwork
    data = query(apikey, "track.getinfo", "track=" + track_name + "&artist=" + artist_name)
    if data == None:
        return None

    if nested_keys_exist(data, ["track", "album", "image", 0, "#text"]) == False:
        return None
    artwork = data["track"]["album"]["image"][0]["#text"]

    return {
        "plays": top_track["playcount"],
        "name": top_track["name"],
        "artwork": artwork,
    }

def query(apikey, method, extra = ""):
    """Query last.fm API with the given method and parameters

    Args:
      apikey: Last.fm API Key
      method: method defined in last.fm API
      extra: Additional parameters to add to end of query

    Returns:
      JSON object of response or None for failed queries
    """

    url = "http://ws.audioscrobbler.com/2.0/?method=" + method
    if extra != "":
        url += "&" + extra
    url += "&format=json&api_key=" + apikey
    resp = http.get(url, ttl_seconds = 600)
    if resp.status_code != 200:
        return None
    return resp.json()

def get_artwork_from_spotify(artist_name):
    """Attempt to get artwork from spotify

    Args:
      artist_name: Artist to search Spotify for

    Returns:
      Either a URL with the artwork or None if failed
    """

    # Login as anonymous user to retrieve a token
    resp = http.get("https://open.spotify.com/get_access_token?reason=transport&productType=web_player", ttl_seconds = 600)
    if resp.status_code != 200:
        return None
    data = resp.json()
    if "accessToken" not in data:
        return None
    token = data["accessToken"]

    # Use that token to query spotify artists
    resp = http.get(
        "https://api.spotify.com/v1/search?type=artist&q=" + humanize.url_encode(artist_name) + "&decorate_restrictions=false&best_match=true&include_external=audio&limit=1",
        headers = {"Authorization": "Bearer " + token},
        ttl_seconds = 600,
    )
    if resp.status_code != 200:
        return None

    # Attempt to pull the top image from the best match
    data = resp.json()
    if nested_keys_exist(data, ["best_match", "items", 0, "images", 0, "url"]) == False:
        return None

    # Success!
    return data["best_match"]["items"][0]["images"][0]["url"]

# Checks if nested keys exist in an object
# Ex: obj = { "a": { "b" : { "c" : 1 } } }, calling nested_keys_exist(obj,["a","b","c"]) would return true
def nested_keys_exist(object, keys):
    """Helper function to check if nested keys exist inside of a dict or list

    Args:
      object: Object to search through. It can be a dict or a list.
      keys: Keys to check for. These can be strings or numbers.

    Returns:
      True if all nested keys were found, False otherwise
    """

    if len(keys) == 0:
        return True
    key = keys.pop(0)

    if type(object) == "dict":
        if key not in object:
            return False
    elif type(object) == "list":
        if len(object) <= key:
            return False
    else:
        return False

    return nested_keys_exist(object[key], keys)
