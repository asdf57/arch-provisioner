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

    # Ansible connection details
    ansible_host = config.ansible.host
    ansible_port = config.ansible.port
    ansible_user = config.ansible.user
    inventory = ",".join(config.ansible.inventory) + ","
    ansible_ssh_private_key_file = config.ansible.private_key
    playbook = config.ansible.playbook

    # Disk configuration
    disk_device = config.disk.device

    # Partitions
    efi_partition = next((p for p in config.disk.partitions if p.type == 'efi'), None)
    swap_partition = next((p for p in config.disk.partitions if p.type == 'swap'), None)
    general_partitions = [p for p in config.disk.partitions if p.type == 'general']

    # System configuration
    root_password = config.root_password
    hostname = config.hostname
    locale = config.locale
    username = config.users[0].username
    password = config.users[0].password

    client_id = gen_client_id()

    ansible_command = [
        'ansible-playbook', '-i', inventory,
        '-e', f'ansible_host={ansible_host}',
        '-e', f'ansible_port={ansible_port}',
        '-e', f'ansible_user={ansible_user}',
        '-e', f'ansible_ssh_private_key_file={ansible_ssh_private_key_file}',
        '-e', f'disk_device={disk_device}',
        '-e', f'efi_partition_number={efi_partition.number}',
        '-e', f'efi_partition_align={efi_partition.align}',
        '-e', f'efi_partition_flags={efi_partition.flags}',
        '-e', f'efi_partition_fs={efi_partition.fs}',
        '-e', f'efi_partition_label={efi_partition.label}',
        '-e', f'efi_partition_name={efi_partition.name}',
        '-e', f'efi_partition_start={efi_partition.start}',
        '-e', f'efi_partition_end={efi_partition.end}',
        '-e', f'efi_partition_resize={efi_partition.resize}',
        '-e', f'efi_partition_state={efi_partition.state}',
        '-e', f'efi_partition_unit={efi_partition.unit}',
        '-e', f'has_swap_partition={swap_partition is not None}',
        '-e', f'swap_partition_number={swap_partition.number if swap_partition else ""}',
        '-e', f'swap_partition_align={swap_partition.align if swap_partition else ""}',
        '-e', f'swap_partition_flags={swap_partition.flags if swap_partition else ""}',
        '-e', f'swap_partition_fs={swap_partition.fs if swap_partition else ""}',
        '-e', f'swap_partition_label={swap_partition.label if swap_partition else ""}',
        '-e', f'swap_partition_name={swap_partition.name if swap_partition else ""}',
        '-e', f'swap_partition_start={swap_partition.start if swap_partition else ""}',
        '-e', f'swap_partition_end={swap_partition.end if swap_partition else ""}',
        '-e', f'swap_partition_resize={swap_partition.resize if swap_partition else ""}',
        '-e', f'swap_partition_state={swap_partition.state if swap_partition else ""}',
        '-e', f'swap_partition_unit={swap_partition.unit if swap_partition else ""}',
        '-e', f'general_partitions={general_partitions}',
        '-e', f'root_password={root_password}',
        '-e', f'locale={locale}',
        '-e', f'hostname={hostname}',
        '-e', f'username={username}',
        '-e', f'password={password}',
        playbook
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
