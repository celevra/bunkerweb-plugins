from traceback import format_exc

def pre_render(**kwargs):
    pass


def slack(**kwargs):
    ping = {"ping_status": "unknown"}

    args = kwargs.get("args", False)
    if not args:
        return {**ping}

    is_ping = args.get("ping", False)
    if not is_ping:
        return {**ping}

    # Check ping
    try:
        ping_data = kwargs["app"].config["INSTANCES"].get_ping("slack")
        ping = {"ping_status": ping_data["status"]}
    except:
        print(f"Error while trying to ping slac : {format_exc()}", flush=True)  
        ping = {"ping_status": "error"}

    return {**ping}
