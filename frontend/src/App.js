import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
  AppShell,
  Group,
  Title,
  Text,
  Button,
  List,
  Stack,
  Progress,
  Container,
  Paper,
  Slider,
  ActionIcon,
  Accordion,
  Image,
  Flex,
  Box,
  rem,
  useMantineTheme,
  Divider,
  ScrollArea,
  Card,
  Center,
  MantineProvider
} from '@mantine/core';
import {
  IconPlayerPlay,
  IconPlayerPause,
  IconPlayerTrackNext,
  IconPlayerTrackPrev,
  IconVolume,
  IconVolumeOff,
  IconRepeat,
  IconMusic,
  IconHistory,
  IconList,
  IconAlbum
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
  
  const fetchPlayerState = async () => {
    try {
      const response = await axios.get('/api/player_state');
      setPlayerState({
        ...response.data,
        // If no album image is provided by the API, we'll use a placeholder
        albumImage: response.data.albumImage || null
      });
    } catch (error) {
      console.error('Error fetching player state:', error);
    }
  };
  
  useEffect(() => {
    fetchPlayerState();
    const interval = setInterval(fetchPlayerState, 5000);
    return () => clearInterval(interval);
  }, []);
  
  const handleAction = async (action, param = null) => {
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
  };

  // Format time in mm:ss
  const formatTime = (seconds) => {
    if (!seconds) return '0:00';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };
  
  return (
    <MantineProvider theme={{ ...theme, colorScheme }} withGlobalStyles withNormalizeCSS>
      <AppShell
        padding="md"
        header={{ height: 60 }}
        styles={{
          main: {
            background: mantineTheme.colors.dark[8],
          },
        }}
      >
        <AppShell.Header style={{ 
          background: mantineTheme.colors.dark[8],
          borderBottom: '1px solid',
          borderColor: mantineTheme.colors.dark[6]
        }}>
          {/* Center title with flex layout */}
          <Flex 
            h="100%" 
            justify="center" 
            align="center"
          >
            <Title order={3} c="white">SLAB ONE</Title>
          </Flex>
        </AppShell.Header>
          
        <AppShell.Main>
          <Container size="lg" py="md">
            <Flex
              direction="column"
              gap="xl"
              justify="flex-start"
              align="stretch"
              mb="xl"
            >
              <Flex
                direction={{ base: 'column', md: 'row' }}
                gap="xl"
                justify="flex-start"
                align={{ base: 'center', md: 'flex-start' }}
                mb="xl"
              >
                <Box w={{ base: '100%', md: 300 }} maw={300}>
                  <Card shadow="sm" p="lg" radius="md" withBorder>
                    <Card.Section>
                      {playerState.albumImage ? (
                        <Image
                          src={playerState.albumImage}
                          height={300}
                          alt="Album cover"
                        />
                      ) : (
                        <Center p="xl" h={300} bg={mantineTheme.colors.dark[4]}>
                          <IconAlbum size={100} color={mantineTheme.colors.gray[2]} />
                        </Center>
                      )}
                    </Card.Section>
                    
                    <Stack mt="md" mb="xs">
                      <Title order={3}>{playerState.currentTrack || 'No track playing'}</Title>
                      <Text size="sm" c="dimmed">{playerState.currentAlbum || 'No album'}</Text>
                    </Stack>
                  </Card>
                </Box>
                
                <Box style={{ flex: 1 }}>
                  {playerState.albumTracks.length > 0 && (
                    <Paper shadow="sm" p="lg" withBorder mb="md">
                      <Group position="apart" mb="md">
                        <Title order={4}>Album Tracks</Title>
                        <IconList size={20} />
                      </Group>
                      
                      <List spacing="xs" size="sm" center icon={
                        <Box w={24} h={24} bg={mantineTheme.colors.orange[6]} style={{ borderRadius: '50%' }}>
                          <Center h="100%">
                            <IconMusic size={14} color="white" />
                          </Center>
                        </Box>
                      }>
                        {playerState.albumTracks.map((track, index) => (
                          <List.Item key={index}>
                            <Text>{track}</Text>
                          </List.Item>
                        ))}
                      </List>
                    </Paper>
                  )}
                </Box>
              </Flex>
              
              {/* Player controls that span full width */}
              <Paper 
                shadow="sm" 
                p="lg" 
                withBorder 
                style={{
                  background: mantineTheme.colors.dark[6],
                }}
              >
                <Stack spacing="md" align="center">
                  {/* Playback controls - centered */}
                  <Group position="center" spacing="md">
                    <ActionIcon 
                      variant="subtle" 
                      color="orange" 
                      size="lg"
                      onClick={() => handleAction('prev_track')}
                    >
                      <IconPlayerTrackPrev style={{ width: rem(24), height: rem(24) }} />
                    </ActionIcon>
                    
                    <ActionIcon 
                      variant="filled" 
                      color="orange" 
                      size="xl"
                      radius="xl"
                      onClick={() => handleAction('toggle_play_pause')}
                    >
                      {playerState.isPlaying ? 
                        <IconPlayerPause style={{ width: rem(30), height: rem(30) }} /> : 
                        <IconPlayerPlay style={{ width: rem(30), height: rem(30) }} />
                      }
                    </ActionIcon>
                    
                    <ActionIcon 
                      variant="subtle" 
                      color="orange" 
                      size="lg"
                      onClick={() => handleAction('next_track')}
                    >
                      <IconPlayerTrackNext style={{ width: rem(24), height: rem(24) }} />
                    </ActionIcon>
                    
                    <ActionIcon 
                      variant={playerState.repeatPlayback ? "filled" : "subtle"}
                      color="orange" 
                      size="lg"
                      onClick={() => handleAction('toggle_repeat_playback')}
                    >
                      <IconRepeat style={{ width: rem(24), height: rem(24) }} />
                    </ActionIcon>
                  </Group>
                  
                  {/* Progress bar with times on either end */}
                  <Box style={{ width: '100%', maxWidth: '600px' }}>
                    <Progress 
                      value={(playerState.position / playerState.length) * 100 || 0} 
                      size="sm" 
                      radius="xl"
                      color="orange"
                    />
                    <Group position="apart" mt={5}>
                      <Text size="xs">{formatTime(playerState.position)}</Text>
                      <Text size="xs">{formatTime(playerState.length)}</Text>
                    </Group>
                  </Box>
                  
                  {/* Volume controls - centered */}
                  <Group position="center" style={{ width: '100%', maxWidth: '500px' }}>
                    <ActionIcon 
                      variant="subtle" 
                      color="orange"
                      onClick={() => handleAction('set_volume', playerState.volume > 0 ? 0 : 70)}
                    >
                      {playerState.volume > 0 ? 
                        <IconVolume style={{ width: rem(18), height: rem(18) }} /> : 
                        <IconVolumeOff style={{ width: rem(18), height: rem(18) }} />
                      }
                    </ActionIcon>
                    
                    <Slider
                      style={{ flex: 1 }}
                      value={playerState.volume}
                      onChange={(value) => handleAction('set_volume', value)}
                      size="sm"
                      radius="xl"
                      label={null}
                      color="orange"
                    />
                    
                    <Text size="sm" w={40} ta="right">{playerState.volume}%</Text>
                  </Group>
                </Stack>
              </Paper>
              
              {/* Log Messages Accordion - Moved below player controls */}
              <Accordion variant="contained">
                <Accordion.Item value="logs">
                  <Accordion.Control icon={<IconHistory size={20} />}>
                    <Title order={5}>Log Messages</Title>
                  </Accordion.Control>
                  <Accordion.Panel>
                    <ScrollArea h={200}>
                      <Box>
                        {playerState.logs.map((log, index) => (
                          <Text key={index} size="xs" ff="monospace">{log}</Text>
                        ))}
                      </Box>
                    </ScrollArea>
                  </Accordion.Panel>
                </Accordion.Item>
              </Accordion>
            </Flex>
          </Container>
        </AppShell.Main>
      </AppShell>
    </MantineProvider>
  );
}

export default App; 