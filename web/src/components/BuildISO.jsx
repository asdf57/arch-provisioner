import React, { useState, useEffect } from 'react';
import {
  Container, Typography, Button, Box, Paper, List, ListItem, ListItemButton,
  ListItemIcon, ListItemText, CircularProgress, Collapse, LinearProgress
} from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import RadioButtonUncheckedIcon from '@mui/icons-material/RadioButtonUnchecked';
import ErrorIcon from '@mui/icons-material/Error';
import ExpandLess from '@mui/icons-material/ExpandLess';
import ExpandMore from '@mui/icons-material/ExpandMore';

const checkpoints = [
    "Initializing",
    "Loading Data",
    "Processing Data",
    "Finalizing",
    "Complete"
  ];
  

const BuildISO = () => {
    const [activeStep, setActiveStep] = useState(0);
    const [progress, setProgress] = useState(0);
    const [errors, setErrors] = useState([]);
    const [open, setOpen] = useState(null);
  
    useEffect(() => {
      if (activeStep < checkpoints.length - 1) {
        const timer = setTimeout(() => {
          if (activeStep === 2) {
            setErrors((prevErrors) => [...prevErrors, { step: activeStep, message: 'Error processing data' }]);
          } else {
            setActiveStep((prevStep) => prevStep + 1);
            setProgress(((activeStep + 1) / (checkpoints.length - 1)) * 100);
          }
        }, 2000);
        return () => clearTimeout(timer);
      }
    }, [activeStep]);
  
    const handleClick = (index) => {
      setOpen(open === index ? null : index);
    };
  
  return (
    <Container maxWidth="md">
        <Box my={4}>
        <Typography variant="h4" component="h1" gutterBottom>
          Build ISO
        </Typography>
      </Box>
        <Box my={4}>
            <Typography variant="h5" component="h2" gutterBottom>
              Checkpoint Process Simulation
            </Typography>
            <LinearProgress variant="determinate" value={progress} sx={{ marginBottom: 2 }} />
            <Paper elevation={3} sx={{ padding: 2 }}>
              <List sx={{ width: '100%', bgcolor: 'background.paper' }}>
                {checkpoints.map((checkpoint, index) => (
                  <React.Fragment key={checkpoint}>
                    <ListItem
                      secondaryAction={
                        errors.find(error => error.step === index) ? (open === index ? <ExpandLess /> : <ExpandMore />) : null
                      }
                      disablePadding
                    >
                      <ListItemButton onClick={() => errors.find(error => error.step === index) && handleClick(index)} dense>
                        <ListItemIcon>
                          {errors.find(error => error.step === index) ? (
                            <ErrorIcon color="error" />
                          ) : index < activeStep ? (
                            <CheckCircleIcon color="success" />
                          ) : index === activeStep ? (
                            <CircularProgress size={24} />
                          ) : (
                            <RadioButtonUncheckedIcon color="disabled" />
                          )}
                        </ListItemIcon>
                        <ListItemText
                          primary={checkpoint}
                          primaryTypographyProps={{
                            color: index === activeStep ? 'primary' : 'textSecondary',
                          }}
                        />
                      </ListItemButton>
                    </ListItem>
                    {index < checkpoints.length - 1 && (
                      <div className="line"></div>
                    )}
                    {errors.find(error => error.step === index) && (
                      <Collapse in={open === index} timeout="auto" unmountOnExit>
                        <Box ml={4} my={1}>
                          <Typography variant="body2" color="error">
                            {errors.find(error => error.step === index)?.message}
                          </Typography>
                        </Box>
                      </Collapse>
                    )}
                  </React.Fragment>
                ))}
              </List>
              <Button
                variant="contained"
                color="primary"
                onClick={() => {
                  setActiveStep(0);
                  setProgress(0);
                  setErrors([]);
                  setOpen(null);
                }}
                fullWidth
              >
                Reset Process
              </Button>
            </Paper>
          </Box>
        </Container>
  );
};

export default BuildISO;
