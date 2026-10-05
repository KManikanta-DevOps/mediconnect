from unittest.mock import MagicMock
from app.main import process, render


def test_render():
    s, b = render({"starts_at": "2030-01-01T10:00", "appointment_id": 7})
    assert "#7" in b and s


def test_process_sends_email():
    ses = MagicMock()
    process({"email": "a@b.com", "starts_at": "x", "appointment_id": 1}, ses)
    ses.send_email.assert_called_once()
