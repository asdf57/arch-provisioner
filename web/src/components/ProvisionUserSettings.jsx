import React, { useContext } from 'react';
import { ProvisionContext } from '../contexts/ProvisionContext';
import { Paper, Typography, Grid, TextField } from '@mui/material';

const ProvisionUserSettings = () => {
  const { options, handleChange } = useContext(ProvisionContext);

  return (
    <Paper elevation={3} sx={{ padding: 3 }}>
      <Typography variant="h5" component="h2" gutterBottom>
        User Credentials
      </Typography>
      <form>
        <Grid container spacing={3}>
          <Grid item xs={6}>
            <TextField
              label="Username"
              name="users[0].username"
              value={options.users[0].username}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Password"
              name="users[0].password"
              value={options.users[0].password}
              onChange={handleChange}
              type="password"
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Root Password"
              name="root_password"
              value={options.root_password}
              onChange={handleChange}
              type="password"
              fullWidth
              required
            />
          </Grid>
        </Grid>
      </form>
    </Paper>
  );
};

export default ProvisionUserSettings;
