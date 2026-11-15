from hermes_personal.server import mcp


def test_public_surface_is_small():
    assert {tool.name for tool in mcp._tool_manager.list_tools()} == {
        "campus_login_start",
        "campus_login_submit",
        "campus_status",
        "lexue_calendar",
        "lexue_courses",
        "mail_list",
    }
