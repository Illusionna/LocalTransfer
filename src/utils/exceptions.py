class RemoveFailException(Exception):
    def __init__(self, *args, message: str, **kwargs):
        super().__init__(*args, message, **kwargs)


class RegistryException(Exception):
    def __init__(self, *args, message: str, **kwargs):
        super().__init__(*args, message, **kwargs)


class SocketException(Exception):
    def __init__(self, *args, message: str, **kwargs):
        super().__init__(*args, message, **kwargs)