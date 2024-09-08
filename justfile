venv:
    python3 -m venv /tmp/.venv

install: venv
    /tmp/.venv/bin/pip install -r requirements.txt > /dev/null

test: venv install
    source /tmp/.venv/bin/activate && python -m pytest tests/test.py -v

# Default task
default: test
