import React, { useState, useEffect, useCallback } from 'react';
import axios from 'axios';
import {
  AppShell,
  Group,
  Title,
  Text,
  List,
  Stack,
  Progress,
  Container,
  Paper,
  Slider,
  ActionIcon,
  Image,
  Flex,
  Box,
  rem,
  useMantineTheme,
  ScrollArea,
  Card,
  Center,
  MantineProvider,
  Drawer,
  Popover,
  Button
} from '@mantine/core';
import {
  IconPlayerPlay,
  IconPlayerPause,
  IconPlayerTrackNext,
  IconPlayerTrackPrev,
  IconVolume,
  IconVolumeOff,
  IconMusic,
  IconHistory,
  IconList,
  IconAlbum,
  IconChevronUp,
  IconMaximize,
  IconLayoutList
} from '@tabler/icons-react';
import { theme } from './theme';

function App() {
  // Set a fixed dark mode
  const colorScheme = 'dark';
  const mantineTheme = useMantineTheme();
  
  const [playerState, setPlayerState] = useState({
    currentAlbum: '',
    currentTrack: '',
    albumTracks: [],
    volume: 70,
    isPlaying: false,
    repeatPlayback: false,
    logs: [],
    albumImage: null,
    position: 0,
    length: 0
  });
  
  // State for log drawer
  const [logsDrawerOpen, setLogsDrawerOpen] = useState(false);
  
  // State for volume popover
  const [volumePopoverOpened, setVolumePopoverOpened] = useState(false);
  
  // State for view mode (true = full screen album view, false = detailed view)
  const [fullScreenMode, setFullScreenMode] = useState(true);
  
  const fetchPlayerState = useCallback(async () => {
    try {
      const response = await axios.get('/api/player_state');
      setPlayerState({
        ...response.data,
        // If no album image is provided by the API, we'll use a placeholder
        albumImage: response.data.albumImage || null,
        // Ensure repeat is on by default in album view
        repeatPlayback: fullScreenMode ? true : response.data.repeatPlayback
      });
    } catch (error) {
      console.error('Error fetching player state:', error);
    }
  }, [fullScreenMode]);
  
  useEffect(() => {
    fetchPlayerState();
    const interval = setInterval(fetchPlayerState, 5000);
    return () => clearInterval(interval);
  }, [fetchPlayerState]);
  
  const handleAction = useCallback(async (action, param = null) => {
    try {
      let url = `/api/${action}`;
      if (param !== null) {
        url += `/${param}`;
      }
      await axios.post(url);
      fetchPlayerState();
    } catch (error) {
      console.error(`Error with action ${action}:`, error);
    }
  }, [fetchPlayerState]);

  // Format time in mm:ss
  const formatTime = (seconds) => {
    if (!seconds) return '0:00';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };
  
  // Full screen album view component
  const FullScreenAlbumView = () => (
    <Flex 
      direction="column" 
      align="center" 
      justify="center" 
      style={{ 
        height: 'calc(100vh - 120px)',
        width: '100%',
        maxWidth: '100%',
        padding: '0 20px'
      }}
    >
      {/* Album cover */}
      <Box 
        style={{ 
          width: '100%', 
          maxWidth: '400px',
          marginBottom: '1rem'
        }}
      >
        <Card 
          shadow="sm" 
          p={0}
          radius="md" 
          withBorder={false}
          style={{ 
            backgroundColor: mantineTheme.colors.dark[7],
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            border: 'none',
            boxShadow: 'none'
          }}
        >
          <Card.Section style={{ width: '100%' }}>
            {playerState.albumImage ? (
              <Image
                src={playerState.albumImage}
                height={{ base: 250, md: 300 }}
                alt="Album cover"
                fit="contain"
                style={{ backgroundColor: mantineTheme.colors.dark[6] }}
              />
            ) : (
              <Center p="xl" h={{ base: 250, md: 300 }} bg={mantineTheme.colors.dark[6]}>
                <IconAlbum size={100} color={mantineTheme.colors.gray[2]} />
              </Center>
            )}
          </Card.Section>
        </Card>
      </Box>
      
      {/* Track info with padding */}
      <Box 
        p="lg" 
        style={{ 
          width: '100%', 
          maxWidth: '400px', 
          textAlign: 'center',
          marginBottom: '1rem'
        }}
      >
        {playerState.currentTrack && (
          <Title order={3} c="white" mb={5}>{playerState.currentTrack}</Title>
        )}
        {playerState.currentAlbum && (
          <Text size="md" c="dimmed">{playerState.currentAlbum}</Text>
        )}
      </Box>
      
      {/* Simplified controls for full screen mode */}
      <Group position="center" spacing="xl" mt="md">
        <ActionIcon 
          variant="subtle" 
          color="orange" 
          size="xl"
          onClick={() => handleAction('prev_track')}
          sx={{ color: '#ff922b' }}
        >
          <IconPlayerTrackPrev color="#ff922b" stroke={2} style={{ width: rem(30), height: rem(30) }} />
        </ActionIcon>
        
        <ActionIcon 
          variant="filled" 
          color="orange" 
          size="xl"
          radius="xl"
          onClick={() => handleAction('toggle_play_pause')}
          style={{ transform: 'scale(1.2)' }}
        >
          {playerState.isPlaying ? 
            <IconPlayerPause color="white" stroke={2} style={{ width: rem(36), height: rem(36) }} /> : 
            <IconPlayerPlay color="white" stroke={2} style={{ width: rem(36), height: rem(36) }} />
          }
        </ActionIcon>
        
        <ActionIcon 
          variant="subtle" 
          color="orange" 
          size="xl"
          onClick={() => handleAction('next_track')}
          sx={{ color: '#ff922b' }}
        >
          <IconPlayerTrackNext color="#ff922b" stroke={2} style={{ width: rem(30), height: rem(30) }} />
        </ActionIcon>
      </Group>
      
      {/* View toggle button - made more prominent */}
      <Button 
        variant="subtle" 
        color="gray" 
        size="md"
        leftIcon={<IconLayoutList style={{ width: rem(18), height: rem(18) }} />}
        onClick={() => setFullScreenMode(false)}
        mt="xl"
      >
        Show Details
      </Button>
    </Flex>
  );
  
  // Player controls component that will be docked at the bottom
  const PlayerControls = () => (
    <Paper 
      shadow="sm" 
      p={{ base: 'md', md: 'md' }}
      withBorder={false}
      style={{
        background: mantineTheme.colors.dark[7],
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        zIndex: 100,
      }}
    >
      <Stack spacing={{ base: 'xs', md: 'sm' }} align="center">
        {/* Progress bar with times on either end */}
        <Box style={{ width: '100%', maxWidth: '800px' }}>
          <Progress 
            value={(playerState.position / playerState.length) * 100 || 0} 
            size="sm" 
            radius="xl"
            color="orange"
          />
          <Flex justify="space-between" mt={5}>
            <Text size="xs" c="white">{formatTime(playerState.position)}</Text>
            <Text size="xs" c="white">{formatTime(playerState.length)}</Text>
          </Flex>
        </Box>
        
        {/* Mobile controls - only visible on mobile */}
        <Flex 
          justify="center" 
          align="center" 
          style={{ width: '100%', maxWidth: '800px' }}
          display={{ base: 'flex', sm: 'none' }}
          gap="xl"
        >
          <Group position="center" spacing="xl">
            {/* Mobile volume control */}
            <Popover 
              opened={volumePopoverOpened} 
              onChange={setVolumePopoverOpened}
              position="top"
              shadow="md"
              withArrow
              styles={{
                dropdown: {
                  background: mantineTheme.colors.dark[7],
                  border: `1px solid ${mantineTheme.colors.dark[5]}`,
                  padding: '15px',
                }
              }}
            >
              <Popover.Target>
                <ActionIcon 
                  variant="subtle" 
                  color="orange"
                  size="lg"
                  onClick={() => setVolumePopoverOpened((o) => !o)}
                  sx={{ color: '#ff922b' }}
                >
                  {playerState.volume > 0 ? 
                    <IconVolume color="#ff922b" stroke={2} style={{ width: rem(18), height: rem(18) }} /> : 
                    <IconVolumeOff color="#ff922b" stroke={2} style={{ width: rem(18), height: rem(18) }} />
                  }
                </ActionIcon>
              </Popover.Target>
              <Popover.Dropdown>
                <Stack spacing="xs" align="center">
                  <Text size="xs" c="white">Volume: {playerState.volume}%</Text>
                  <Slider
                    style={{ width: '150px' }}
                    value={playerState.volume}
                    onChange={(value) => handleAction('set_volume', value)}
                    size="sm"
                    radius="xl"
                    label={null}
                    color="orange"
                    min={0}
                    max={100}
                  />
                  <ActionIcon 
                    variant="subtle" 
                    color="orange"
                    onClick={() => handleAction('set_volume', playerState.volume > 0 ? 0 : 70)}
                    sx={{ color: '#ff922b' }}
                  >
                    {playerState.volume > 0 ? 
                      <IconVolume color="#ff922b" stroke={2} style={{ width: rem(18), height: rem(18) }} /> : 
                      <IconVolumeOff color="#ff922b" stroke={2} style={{ width: rem(18), height: rem(18) }} />
                    }
                  </ActionIcon>
                </Stack>
              </Popover.Dropdown>
            </Popover>
            
            <ActionIcon 
              variant="subtle" 
              color="orange" 
              size="lg"
              onClick={() => handleAction('prev_track')}
              sx={{ color: '#ff922b' }}
            >
              <IconPlayerTrackPrev color="#ff922b" stroke={2} style={{ width: rem(24), height: rem(24) }} />
            </ActionIcon>
            
            <ActionIcon 
              variant="filled" 
              color="orange" 
              size="xl"
              radius="xl"
              onClick={() => handleAction('toggle_play_pause')}
            >
              {playerState.isPlaying ? 
                <IconPlayerPause color="white" stroke={2} style={{ width: rem(30), height: rem(30) }} /> : 
                <IconPlayerPlay color="white" stroke={2} style={{ width: rem(30), height: rem(30) }} />
              }
            </ActionIcon>
            
            <ActionIcon 
              variant="subtle" 
              color="orange" 
              size="lg"
              onClick={() => handleAction('next_track')}
              sx={{ color: '#ff922b' }}
            >
              <IconPlayerTrackNext color="#ff922b" stroke={2} style={{ width: rem(24), height: rem(24) }} />
            </ActionIcon>
            
            {/* Logs button - mobile only */}
            <ActionIcon 
              variant="subtle" 
              color="gray" 
              size="lg"
              onClick={() => setLogsDrawerOpen(true)}
              title="Show logs"
            >
              <IconChevronUp style={{ width: rem(18), height: rem(18) }} />
            </ActionIcon>
          </Group>
        </Flex>
        
        {/* Desktop controls - only visible on desktop */}
        <Flex 
          justify="space-between" 
          align="center" 
          style={{ width: '100%', maxWidth: '800px' }}
          display={{ base: 'none', sm: 'flex' }}
          gap="md"
        >
          {/* Track info on the left - desktop only */}
          <Box style={{ flex: 1, maxWidth: '33%' }}>
            <Flex 
              align="center" 
              gap="md" 
              style={{ justifyContent: 'flex-start' }}
            >
              <Box w={50} h={50} style={{ minWidth: 50 }}>
                {playerState.albumImage ? (
                  <Image
                    src={playerState.albumImage}
                    height={50}
                    width={50}
                    alt="Album thumbnail"
                    radius="sm"
                  />
                ) : (
                  <Center h={50} bg={mantineTheme.colors.dark[5]} style={{ borderRadius: '4px' }}>
                    <IconAlbum size={30} color={mantineTheme.colors.gray[2]} />
                  </Center>
                )}
              </Box>
              <Box>
                <Text size="sm" weight={500} lineClamp={1} c="white">
                  {playerState.currentTrack || 'No track playing'}
                </Text>
                <Text size="xs" c="dimmed" lineClamp={1}>
                  {playerState.currentAlbum || 'No album'}
                </Text>
              </Box>
            </Flex>
          </Box>
          
          {/* Desktop playback controls in the center */}
          <Box 
            style={{ 
              flex: 1, 
              display: 'flex', 
              justifyContent: 'center', 
              minWidth: '33%',
            }}
          >
            <Group position="center" spacing="md">
              <ActionIcon 
                variant="subtle" 
                color="orange" 
                size="md"
                onClick={() => handleAction('prev_track')}
                sx={{ color: '#ff922b' }}
              >
                <IconPlayerTrackPrev color="#ff922b" stroke={2} style={{ width: rem(24), height: rem(24) }} />
              </ActionIcon>
              
              <ActionIcon 
                variant="filled" 
                color="orange" 
                size="lg"
                radius="xl"
                onClick={() => handleAction('toggle_play_pause')}
              >
                {playerState.isPlaying ? 
                  <IconPlayerPause color="white" stroke={2} style={{ width: rem(30), height: rem(30) }} /> : 
                  <IconPlayerPlay color="white" stroke={2} style={{ width: rem(30), height: rem(30) }} />
                }
              </ActionIcon>
              
              <ActionIcon 
                variant="subtle" 
                color="orange" 
                size="md"
                onClick={() => handleAction('next_track')}
                sx={{ color: '#ff922b' }}
              >
                <IconPlayerTrackNext color="#ff922b" stroke={2} style={{ width: rem(24), height: rem(24) }} />
              </ActionIcon>
            </Group>
          </Box>
          
          {/* Right side controls - desktop only */}
          <Box style={{ flex: 1, maxWidth: '33%', display: 'flex', justifyContent: 'flex-end' }}>
            <Flex 
              align="center" 
              gap="md" 
            >
              {/* Volume controls - desktop only */}
              <Group spacing="xs">
                <ActionIcon 
                  variant="subtle" 
                  color="orange"
                  onClick={() => handleAction('set_volume', playerState.volume > 0 ? 0 : 70)}
                  sx={{ color: '#ff922b' }}
                >
                  {playerState.volume > 0 ? 
                    <IconVolume color="#ff922b" stroke={2} style={{ width: rem(18), height: rem(18) }} /> : 
                    <IconVolumeOff color="#ff922b" stroke={2} style={{ width: rem(18), height: rem(18) }} />
                  }
                </ActionIcon>
                
                <Slider
                  style={{ width: '100px' }}
                  value={playerState.volume}
                  onChange={(value) => handleAction('set_volume', value)}
                  size="sm"
                  radius="xl"
                  label={null}
                  color="orange"
                />
              </Group>
              
              {/* Logs button - desktop only */}
              <ActionIcon 
                variant="subtle" 
                color="gray" 
                onClick={() => setLogsDrawerOpen(true)}
                title="Show logs"
              >
                <IconChevronUp style={{ width: rem(18), height: rem(18) }} />
              </ActionIcon>
            </Flex>
          </Box>
        </Flex>
      </Stack>
    </Paper>
  );
  
  // Detailed view component
  const DetailedView = () => (
    <Container size="lg" py="md">
      {/* View toggle button - changed to icon button */}
      <ActionIcon 
        variant="filled" 
        color="orange" 
        size="lg"
        onClick={() => setFullScreenMode(true)}
        style={{ 
          position: 'fixed', 
          top: '80px', 
          right: '20px',
          zIndex: 10
        }}
        title="Full Screen View"
      >
        <IconMaximize style={{ width: rem(20), height: rem(20) }} />
      </ActionIcon>
      
      {/* Main content area */}
      <Flex
        direction="column"
        gap="xl"
        justify="flex-start"
        align="stretch"
        mb="xl"
      >
        {/* Album and Tracks section */}
        <Flex
          direction={{ base: 'column', md: 'row' }}
          gap="xl"
          justify="flex-start"
          align={{ base: 'stretch', md: 'flex-start' }}
          mb="xl"
        >
          {/* Album cover on the left */}
          <Box w={{ base: '100%', md: 300 }} maw={{ md: 300 }}>
            <Card 
              shadow="sm" 
              p={0}
              radius="md" 
              withBorder={false}
              h={{ md: 500 }}
              style={{ 
                backgroundColor: mantineTheme.colors.dark[7],
                display: 'flex',
                flexDirection: 'column'
              }}
            >
              <Card.Section style={{ flex: '0 0 auto' }}>
                {playerState.albumImage ? (
                  <Image
                    src={playerState.albumImage}
                    height={{ base: 250, md: 300 }}
                    alt="Album cover"
                    fit="contain"
                    style={{ backgroundColor: mantineTheme.colors.dark[6] }}
                  />
                ) : (
                  <Center p="xl" h={{ base: 250, md: 300 }} bg={mantineTheme.colors.dark[6]}>
                    <IconAlbum size={100} color={mantineTheme.colors.gray[2]} />
                  </Center>
                )}
              </Card.Section>
              
              <Stack mt="md" mb="xs" px="md" style={{ flex: '1 1 auto' }}>
                <Title order={3} c="white">{playerState.currentTrack || 'No track playing'}</Title>
                <Text size="sm" c="dimmed">{playerState.currentAlbum || 'No album'}</Text>
              </Stack>
            </Card>
          </Box>
          
          {/* Tracks list on the right */}
          <Box style={{ flex: 1 }}>
            {playerState.albumTracks.length > 0 ? (
              <Paper 
                shadow="sm" 
                p="lg" 
                radius="md" 
                withBorder={false}
                h={{ md: 500 }}
                style={{ 
                  backgroundColor: mantineTheme.colors.dark[7],
                  display: 'flex',
                  flexDirection: 'column'
                }}
              >
                <Group position="apart" mb="md" style={{ flex: '0 0 auto' }}>
                  <Title order={4} c="white">Album Tracks</Title>
                  <IconList size={20} />
                </Group>
                
                <ScrollArea style={{ flex: '1 1 auto' }}>
                  <List spacing="xs" size="sm" center icon={
                    <Box w={24} h={24} bg={mantineTheme.colors.orange[6]} style={{ borderRadius: '50%' }}>
                      <Center h="100%">
                        <IconMusic size={14} color="white" />
                      </Center>
                    </Box>
                  }>
                    {playerState.albumTracks.map((track, index) => (
                      <List.Item key={index}>
                        <Text c="white">{track}</Text>
                      </List.Item>
                    ))}
                  </List>
                </ScrollArea>
              </Paper>
            ) : (
              <Paper 
                shadow="sm" 
                p="lg" 
                radius="md" 
                withBorder={false}
                h={{ md: 500 }}
                style={{ 
                  backgroundColor: mantineTheme.colors.dark[7],
                  display: 'flex',
                  flexDirection: 'column',
                  justifyContent: 'center'
                }}
              >
                <Center p="xl">
                  <Text c="dimmed">No tracks available</Text>
                </Center>
              </Paper>
            )}
          </Box>
        </Flex>
      </Flex>
    </Container>
  );
  
  // Ensure repeat is turned on when switching to album view
  useEffect(() => {
    if (fullScreenMode && !playerState.repeatPlayback) {
      handleAction('toggle_repeat_playback');
    }
  }, [fullScreenMode, playerState.repeatPlayback, handleAction]);
  
  return (
    <MantineProvider theme={{ ...theme, colorScheme }} withGlobalStyles withNormalizeCSS>
      <AppShell
        padding="md"
        header={{ height: 60 }}
        styles={{
          main: {
            background: mantineTheme.colors.dark[8],
            paddingBottom: { base: '100px', sm: '120px' }, // Responsive padding for the player controls
            color: 'white', // Explicitly set text color for the main content
          },
        }}
      >
        <AppShell.Header style={{ 
          background: mantineTheme.colors.dark[8],
          borderBottom: 'none'
        }}>
          {/* Center title with flex layout */}
          <Flex 
            h="100%" 
            justify="center" 
            align="center"
          >
            <Title order={3}>
              <Text span c="#ff922b" inherit>SLAB</Text>
              <Text span c="white" inherit> ONE</Text>
            </Title>
          </Flex>
        </AppShell.Header>
          
        <AppShell.Main>
          {/* Conditional rendering based on view mode */}
          {fullScreenMode ? <FullScreenAlbumView /> : <DetailedView />}
        </AppShell.Main>
        
        {/* Player Controls docked at the bottom - only shown in detailed view */}
        {!fullScreenMode && <PlayerControls />}
        
        {/* Logs Drawer that slides up from the bottom */}
        <Drawer
          opened={logsDrawerOpen}
          onClose={() => setLogsDrawerOpen(false)}
          position="bottom"
          size="md"
          title={
            <Group>
              <IconHistory size={20} />
              <Title order={5} c="white">Log Messages</Title>
            </Group>
          }
          styles={{
            header: {
              background: mantineTheme.colors.dark[7],
              borderBottom: `1px solid ${mantineTheme.colors.dark[5]}`,
            },
            body: {
              background: mantineTheme.colors.dark[7],
            }
          }}
        >
          <ScrollArea h={300}>
            <Box p="md">
              {playerState.logs.length > 0 ? (
                playerState.logs.map((log, index) => (
                  <Text key={index} size="xs" ff="monospace" mb={5} c="white">{log}</Text>
                ))
              ) : (
                <Center>
                  <Text c="dimmed">No log messages available</Text>
                </Center>
              )}
            </Box>
          </ScrollArea>
        </Drawer>
      </AppShell>
    </MantineProvider>
  );
}

export default App;