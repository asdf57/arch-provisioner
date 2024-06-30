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

const supportedFilesystems = [
  'ext3',
  'ext4',
  'fat',
  'exfat',
  'f2fs',
  'hfsplus',
  'jfs',
  'nilfs2',
  'ntfs',
  'reiserfs',
  'udf',
  'xfs',
  'btrfs',
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
              label="Ansible Port"
              name="ansible.port"
              value={options.ansible.port}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
        <Grid item xs={12}>
            <TextField
              label="Playbook Path"
              name="ansible.playbook"
              value={options.ansible.playbook}
              onChange={handleChange}
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
              name="disk.size"
              value={options.disk.size}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              label="Disk Device"
              name="disk.device"
              value={options.disk.device}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Boot Partition Min"
              name="disk.partitions[0].min"
              value={options.disk.partitions[0].min}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Boot Partition Max"
              name="disk.partitions[0].max"
              value={options.disk.partitions[0].max}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Swap Partition Min"
              name="disk.partitions[1].min"
              value={options.disk.partitions[1].min}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Swap Partition Max"
              name="disk.partitions[1].max"
              value={options.disk.partitions[1].max}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Root Partition Min"
              name="disk.partitions[2].min"
              value={options.disk.partitions[2].min}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={6}>
            <TextField
              label="Root Partition Max"
              name="disk.partitions[2].max"
              value={options.disk.partitions[2].max}
              onChange={handleChange}
              fullWidth
              required
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              select
              label="Root Filesystem"
              name="disk.partitions[2].fs"
              value={options.disk.partitions[2].fs}
              onChange={handleChange}
              fullWidth
              required
            >
              {supportedFilesystems.map((fs) => (
                <MenuItem key={fs} value={fs}>
                  {fs}
                </MenuItem>
              ))}
            </TextField>
          </Grid>
        </Grid>
      </form>
    </Paper>
  );
};

export default ProvisionDiskSettings;
