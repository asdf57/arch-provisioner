import React, { useContext } from 'react';
import { ProvisionContext } from '../contexts/ProvisionContext';
import { Paper, Typography, Grid, TextField, MenuItem } from '@mui/material';

const supportedLocales = [
  'en_US.UTF-8',
  'de_DE.UTF-8',
  'fr_FR.UTF-8',
  'es_ES.UTF-8',
  'zh_CN.UTF-8'
];

const ProvisionDiskSettings = () => {
  const { options, handleChange } = useContext(ProvisionContext);

  return (
    <Paper elevation={3} sx={{ padding: 3 }}>
      <Typography variant="h5" component="h2" gutterBottom>
        System Settings
      </Typography>
      <form>
        <Grid container spacing={3}>
          <Grid item xs={12}>
            <TextField
              label="ISO Path"
              name="iso_path"
              value={options.iso_path}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="CPU Count"
              name="cpu_count"
              value={options.cpu_count}
              onChange={handleChange}
              type="number"
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="RAM Size (MB)"
              name="ram_size"
              value={options.ram_size}
              onChange={handleChange}
              type="number"
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              select
              label="Locale"
              name="locale"
              value={options.locale}
              onChange={handleChange}
              fullWidth
              required
            >
              {supportedLocales.map((locale) => (
                <MenuItem key={locale} value={locale}>
                  {locale}
                </MenuItem>
              ))}
            </TextField>
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Hostname"
              name="hostname"
              value={options.hostname}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
        </Grid>
      </form>

      <Typography variant="h5" component="h2" gutterBottom mt={3}>
        Disk Provisioning
      </Typography>
      <form>
        <Grid container spacing={3}>
          <Grid item xs={12}>
            <TextField
              label="Disk Size"
              name="disk_size"
              value={options.disk_size}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              label="Disk Device"
              name="disk_device"
              value={options.disk_device}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Boot Partition Min"
              name="boot_partition_min"
              value={options.boot_partition_min}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Boot Partition Max"
              name="boot_partition_max"
              value={options.boot_partition_max}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Swap Partition Min"
              name="swap_partition_min"
              value={options.swap_partition_min}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Swap Partition Max"
              name="swap_partition_max"
              value={options.swap_partition_max}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Root Partition Min"
              name="root_partition_min"
              value={options.root_partition_min}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Root Partition Max"
              name="root_partition_max"
              value={options.root_partition_max}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              label="Root Filesystem"
              name="root_filesystem"
              value={options.root_filesystem}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
        </Grid>
      </form>
    </Paper>
  );
};

export default ProvisionDiskSettings;
