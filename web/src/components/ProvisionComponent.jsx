import React, { useEffect, useState, useRef, useContext } from 'react';
import ProvisionUserSettings from './ProvisionUserSettings';
import ProvisionDiskSettings from './ProvisionDiskSettings';
import ProvisionPackageSettings from './ProvisionPackageSettings';
import { ProvisionContext } from '../contexts/ProvisionContext';
import io from 'socket.io-client';
import { Box, Typography, Button, Grid, Paper, Container } from '@mui/material';

const ProvisionComponent = () => {
  const { options } = useContext(ProvisionContext);
  const [clientId, setClientId] = useState(null);
  const [output, setOutput] = useState([]);
  const socket = useRef(null);

  useEffect(() => {
    if (clientId) {
      console.log('Setting up socket with clientId:', clientId);
      socket.current = io('http://localhost:5001', { query: { clientId } });

      socket.current.on('connect', () => {
        console.log('Socket connected:', socket.current.id);
      });

      socket.current.on('ansible_output', (data) => {
        console.log('Received ansible_output:', data);
        setOutput((prevOutput) => [...prevOutput, data.data]);
      });

      socket.current.on('disconnect', () => {
        console.log('Socket disconnected');
      });

      socket.current.on('connect_error', (err) => {
        console.error('Connection error:', err);
      });

      return () => {
        if (socket.current) {
          console.log('Disconnecting socket');
          socket.current.disconnect();
        }
      };
    }
  }, [clientId]);

  const handleRunAnsible = async () => {
    try {
      console.log('Options sent:', options);
      const response = await fetch('http://localhost:5001/run-ansible', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(options),
      });
      const data = await response.json();
      console.log('Response:', data);

      const provisionText = `Provisioning machine with the following settings: ${JSON.stringify(options)}`;
      setOutput((prevOutput) => [...prevOutput, provisionText]);

      if (data.client_id) {
        setClientId(data.client_id);
      }
    } catch (error) {
      console.error('Error:', error);
    }
  };

  return (
    <Container maxWidth="md">
      <Box my={4}>
        <Typography variant="h4" component="h1" gutterBottom>
          Provision Machine(s)
        </Typography>
      </Box>
      <Grid container spacing={4}>
        <Grid item xs={12} md={6}>
          <ProvisionDiskSettings />
        </Grid>
        <Grid item xs={12} md={6}>
          <ProvisionUserSettings />
          <ProvisionPackageSettings />
        </Grid>
      </Grid>
      <Box my={4}>
        <Button variant="contained" color="primary" onClick={handleRunAnsible}>
          Run Ansible Playbook
        </Button>
      </Box>
      <Box my={4}>
        <Typography variant="h5" component="h2" gutterBottom>
          Ansible Command Output
        </Typography>
        <Paper elevation={3} sx={{ padding: 2, maxHeight: '400px', overflowY: 'scroll' }}>
          <pre>
            {output.map((line, index) => (
              <div key={index}>{line}</div>
            ))}
          </pre>
        </Paper>
      </Box>
    </Container>
  );
};

export default ProvisionComponent;
