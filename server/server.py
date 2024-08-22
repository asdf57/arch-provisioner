import os
import uuid
import subprocess
import ssl
import eventlet
eventlet.monkey_patch()

from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit
from flask_cors import CORS

from schema import Config

app = Flask(__name__)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")

clients = {}

def gen_client_id():
    return str(uuid.uuid4())

def read_process_output(process, client_id):
    for line in iter(process.stdout.readline, b''):
        print(line.decode('utf-8'))
        socketio.emit('ansible_output', {'data': line.decode('utf-8')}, room=clients.get(client_id))
    process.stdout.close()
    process.wait()
    socketio.emit('ansible_output', {'data': f'Process exited with code {process.returncode}'}, room=clients.get(client_id))


@app.route('/run-ansible', methods=['POST'])
def run_ansible():
    data = request.json

    try:
        config = Config(**data)
        print(config)
    except Exception as e:
        return jsonify({'error': f'Invalid request: {e}'}), 400

    client_id = gen_client_id()

    ansible_command = [
        'ansible-playbook',
        '-i', config.ansible.inventory,
        '-e', f'config={config}',
        config.ansible.playbook
    ]

    env = os.environ.copy()
    env['ANSIBLE_SSH_ARGS'] = '-o StrictHostKeyChecking=no'

    ansible_process = subprocess.Popen(ansible_command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)

    socketio.start_background_task(target=read_process_output, process=ansible_process, client_id=client_id)

    return jsonify({'message': 'Ansible command started. Use the client_id to track progress', 'client_id': client_id})

@socketio.on('connect')
def handle_connect():
    client_id = request.args.get('clientId')
    if client_id:
        clients[client_id] = request.sid
        print(f'Client connected: {client_id}, SID: {request.sid}')
        emit('ansible_output', {'data': f'Client {client_id} connected successfully!'})

@socketio.on('disconnect')
def handle_disconnect():
    client_id = request.args.get('clientId')
    if client_id in clients:
        del clients[client_id]
        print(f'Client disconnected: {client_id}')

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5001)
