import React, { useState, useRef } from 'react';
import { Paper, Typography, TextField, List, Card, CardContent, Box, Checkbox, ListItemText, IconButton, Button } from '@mui/material';
import AddIcon from '@mui/icons-material/Add';
import DeleteIcon from '@mui/icons-material/Delete';

const ProvisionPackageSettings = () => {
  const [checked, setChecked] = useState([]);
  const [packages, setPackages] = useState([]);
  const [newPackage, setNewPackage] = useState('');
  const inputRef = useRef(null);

  const handleAddPackage = () => {
    if (newPackage.trim() !== '') {
      setPackages([...packages, newPackage]);
      setNewPackage('');
    }
  };

  const handleRemovePackage = (index) => {
    setPackages(packages.filter((_, i) => i !== index));
  };

  const handleRemoveSelectedPackages = () => {
    setPackages(packages.filter((_, index) => !checked.includes(index)));
    setChecked([]);
  };

  const handleToggle = (value) => () => {
    const currentIndex = checked.indexOf(value);
    const newChecked = [...checked];

    if (currentIndex === -1) {
      newChecked.push(value);
    } else {
      newChecked.splice(currentIndex, 1);
    }

    setChecked(newChecked);
  };

  return (
    <Paper elevation={3} sx={{ padding: 3, mt: 3 }}>
      <Typography variant="h5" component="h2" gutterBottom>
        Package List
      </Typography>
      <Box display="flex" alignItems="center" mb={2}>
        <TextField
          label="New Package"
          value={newPackage}
          onChange={(e) => setNewPackage(e.target.value)}
          fullWidth
          inputRef={inputRef}
        />
      </Box>
      <List sx={{ width: '100%', bgcolor: 'background.paper' }}>
        {packages.map((pkg, index) => (
          <Card key={index} variant="outlined" sx={{ mb: 2 }}>
            <CardContent>
              <Box display="flex" alignItems="center">
                <Checkbox
                  edge="start"
                  checked={checked.indexOf(index) !== -1}
                  tabIndex={-1}
                  disableRipple
                  onClick={handleToggle(index)}
                />
                <ListItemText primary={pkg} />
                <IconButton edge="end" aria-label="delete" onClick={() => handleRemovePackage(index)}>
                  <DeleteIcon />
                </IconButton>
              </Box>
            </CardContent>
          </Card>
        ))}
      </List>
      <Box display="flex" justifyContent="space-between" mt={2}>
        <Button
          variant="contained"
          color="primary"
          startIcon={<AddIcon />}
          onClick={handleAddPackage}
        >
          Add Package
        </Button>
        <Button
          variant="contained"
          color="secondary"
          startIcon={<DeleteIcon />}
          onClick={handleRemoveSelectedPackages}
          disabled={checked.length === 0}
        >
          Delete Selected
        </Button>
      </Box>
    </Paper>
  );
};

export default ProvisionPackageSettings;
