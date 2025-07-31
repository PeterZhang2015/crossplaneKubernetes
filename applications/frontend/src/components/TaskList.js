import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import {
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Chip,
  IconButton,
  Typography,
  Box,
  Alert,
  CircularProgress,
  Checkbox
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Refresh as RefreshIcon
} from '@mui/icons-material';
import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || '/api';

// API functions
const fetchTasks = async (page = 1, priority = '', completed = null) => {
  const params = new URLSearchParams({ page: page.toString(), per_page: '10' });
  if (priority) params.append('priority', priority);
  if (completed !== null) params.append('completed', completed.toString());
  
  const response = await axios.get(`${API_BASE_URL}/tasks?${params}`);
  return response.data;
};

const createTask = async (task) => {
  const response = await axios.post(`${API_BASE_URL}/tasks`, task);
  return response.data;
};

const updateTask = async ({ id, ...task }) => {
  const response = await axios.put(`${API_BASE_URL}/tasks/${id}`, task);
  return response.data;
};

const deleteTask = async (id) => {
  await axios.delete(`${API_BASE_URL}/tasks/${id}`);
};

const TaskList = () => {
  const [page, setPage] = useState(1);
  const [priorityFilter, setPriorityFilter] = useState('');
  const [completedFilter, setCompletedFilter] = useState(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingTask, setEditingTask] = useState(null);
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    priority: 'medium'
  });

  const queryClient = useQueryClient();

  // Fetch tasks query
  const { data, isLoading, error, refetch } = useQuery(
    ['tasks', page, priorityFilter, completedFilter],
    () => fetchTasks(page, priorityFilter, completedFilter),
    {
      keepPreviousData: true,
    }
  );

  // Mutations
  const createMutation = useMutation(createTask, {
    onSuccess: () => {
      queryClient.invalidateQueries('tasks');
      setDialogOpen(false);
      resetForm();
    },
  });

  const updateMutation = useMutation(updateTask, {
    onSuccess: () => {
      queryClient.invalidateQueries('tasks');
      setDialogOpen(false);
      resetForm();
    },
  });

  const deleteMutation = useMutation(deleteTask, {
    onSuccess: () => {
      queryClient.invalidateQueries('tasks');
    },
  });

  const toggleCompletedMutation = useMutation(updateTask, {
    onSuccess: () => {
      queryClient.invalidateQueries('tasks');
    },
  });

  const resetForm = () => {
    setFormData({ title: '', description: '', priority: 'medium' });
    setEditingTask(null);
  };

  const handleSubmit = () => {
    if (editingTask) {
      updateMutation.mutate({ id: editingTask.id, ...formData });
    } else {
      createMutation.mutate(formData);
    }
  };

  const handleEdit = (task) => {
    setEditingTask(task);
    setFormData({
      title: task.title,
      description: task.description || '',
      priority: task.priority
    });
    setDialogOpen(true);
  };

  const handleDelete = (id) => {
    if (window.confirm('Are you sure you want to delete this task?')) {
      deleteMutation.mutate(id);
    }
  };

  const handleToggleCompleted = (task) => {
    toggleCompletedMutation.mutate({
      id: task.id,
      completed: !task.completed
    });
  };

  const getPriorityColor = (priority) => {
    switch (priority) {
      case 'high': return 'error';
      case 'medium': return 'warning';
      case 'low': return 'success';
      default: return 'default';
    }
  };

  if (isLoading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error">
        Error loading tasks: {error.message}
      </Alert>
    );
  }

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" component="h1">
          Task Management
        </Typography>
        <Box>
          <IconButton onClick={refetch} color="primary">
            <RefreshIcon />
          </IconButton>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={() => setDialogOpen(true)}
            sx={{ ml: 1 }}
          >
            Add Task
          </Button>
        </Box>
      </Box>

      {/* Filters */}
      <Box display="flex" gap={2} mb={3}>
        <FormControl size="small" sx={{ minWidth: 120 }}>
          <InputLabel>Priority</InputLabel>
          <Select
            value={priorityFilter}
            label="Priority"
            onChange={(e) => setPriorityFilter(e.target.value)}
          >
            <MenuItem value="">All</MenuItem>
            <MenuItem value="high">High</MenuItem>
            <MenuItem value="medium">Medium</MenuItem>
            <MenuItem value="low">Low</MenuItem>
          </Select>
        </FormControl>
        
        <FormControl size="small" sx={{ minWidth: 120 }}>
          <InputLabel>Status</InputLabel>
          <Select
            value={completedFilter === null ? '' : completedFilter.toString()}
            label="Status"
            onChange={(e) => {
              const value = e.target.value;
              setCompletedFilter(value === '' ? null : value === 'true');
            }}
          >
            <MenuItem value="">All</MenuItem>
            <MenuItem value="false">Pending</MenuItem>
            <MenuItem value="true">Completed</MenuItem>
          </Select>
        </FormControl>
      </Box>

      {/* Tasks Table */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Status</TableCell>
              <TableCell>Title</TableCell>
              <TableCell>Description</TableCell>
              <TableCell>Priority</TableCell>
              <TableCell>Created</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {data?.tasks?.map((task) => (
              <TableRow key={task.id}>
                <TableCell>
                  <Checkbox
                    checked={task.completed}
                    onChange={() => handleToggleCompleted(task)}
                    color="primary"
                  />
                </TableCell>
                <TableCell>
                  <Typography
                    variant="body2"
                    sx={{
                      textDecoration: task.completed ? 'line-through' : 'none',
                      opacity: task.completed ? 0.6 : 1
                    }}
                  >
                    {task.title}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Typography variant="body2" color="text.secondary">
                    {task.description || '-'}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Chip
                    label={task.priority}
                    color={getPriorityColor(task.priority)}
                    size="small"
                  />
                </TableCell>
                <TableCell>
                  <Typography variant="body2" color="text.secondary">
                    {new Date(task.created_at).toLocaleDateString()}
                  </Typography>
                </TableCell>
                <TableCell>
                  <IconButton
                    size="small"
                    onClick={() => handleEdit(task)}
                    color="primary"
                  >
                    <EditIcon />
                  </IconButton>
                  <IconButton
                    size="small"
                    onClick={() => handleDelete(task.id)}
                    color="error"
                  >
                    <DeleteIcon />
                  </IconButton>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Pagination */}
      <Box display="flex" justifyContent="center" mt={3}>
        <Button
          disabled={page === 1}
          onClick={() => setPage(page - 1)}
        >
          Previous
        </Button>
        <Typography sx={{ mx: 2, alignSelf: 'center' }}>
          Page {page} of {Math.ceil((data?.total || 0) / 10)}
        </Typography>
        <Button
          disabled={page >= Math.ceil((data?.total || 0) / 10)}
          onClick={() => setPage(page + 1)}
        >
          Next
        </Button>
      </Box>

      {/* Add/Edit Dialog */}
      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {editingTask ? 'Edit Task' : 'Add New Task'}
        </DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            label="Title"
            fullWidth
            variant="outlined"
            value={formData.title}
            onChange={(e) => setFormData({ ...formData, title: e.target.value })}
            sx={{ mb: 2 }}
          />
          <TextField
            margin="dense"
            label="Description"
            fullWidth
            multiline
            rows={3}
            variant="outlined"
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            sx={{ mb: 2 }}
          />
          <FormControl fullWidth variant="outlined">
            <InputLabel>Priority</InputLabel>
            <Select
              value={formData.priority}
              label="Priority"
              onChange={(e) => setFormData({ ...formData, priority: e.target.value })}
            >
              <MenuItem value="low">Low</MenuItem>
              <MenuItem value="medium">Medium</MenuItem>
              <MenuItem value="high">High</MenuItem>
            </Select>
          </FormControl>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button
            onClick={handleSubmit}
            variant="contained"
            disabled={!formData.title.trim() || createMutation.isLoading || updateMutation.isLoading}
          >
            {editingTask ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default TaskList;