import '../styles/interfaces/MS13Terminal.scss';

import { useBackend, useLocalState } from '../backend';
import {
  Box,
  Button,
  ByondUi,
  Flex,
  Input,
  NoticeBox,
  Section,
  Tabs,
} from '../components';
import { Window } from '../layouts';
import { sanitizeText } from '../sanitize';
import { SquadPanel } from './MS13Squad';

export const MS13Terminal = () => {
  const { data, act } = useBackend();
  const [search, setSearch] = useLocalState('recipes', '');
  const legacy = (choice, params = {}) => act('legacy', { choice, ...params });
  const pages = [
    [0, 'Home'],
    [5, 'Squad'],
    [6, 'Cryopods'],
    [7, 'Bodycams'],
    [4, 'Workshop'],
    [3, 'Utilities'],
  ];
  if (data.security) pages.push([8, 'Cameras']);
  const systems = {
    ROBCO50: [
      'ROBCO INDUSTRIES UNIFIED OPERATING SYSTEM V.5.0',
      'COPYRIGHT 2075-2077 ROBCO INDUSTRIES',
    ],
    ROBCO38: [
      'ROBCO INDUSTRIES UNIFIED OPERATING SYSTEM V.3.8',
      'COPYRIGHT 2072-2075 ROBCO INDUSTRIES',
    ],
    APRICOT: [
      'APRICOT COMPUTING SYSTEM VERSION 4B',
      'COPYRIGHT 2069-2070 APRICOT COMPUTING INC.',
    ],
    BOOTLEG: [
      'DLLLX00992 SYSTEM VERSION FFFFF23',
      'COPYRIGHT 223333-21065 DLLLX00992 C0MTTTT LLLL.',
    ],
  };
  const heading = systems[data.system] || [data.system, ''];
  return (
    <Window
      width={950}
      height={720}
      title={`${data.terminalTag} Terminal ${data.terminalNumber}`}
      theme="ms13-terminal"
    >
      <Window.Content
        fitted
        className="MS13Terminal"
        style={{
          '--terminal-bg': data.mainColor,
          '--terminal-fg': data.secondaryColor,
        }}
      >
        <Box className="MS13Terminal__header">
          <Box bold>{heading[0]}</Box>
          <Box>{heading[1]}</Box>
          <Box>{`= ${data.terminalTag} Terminal ${data.terminalNumber} =`}</Box>
        </Box>
        <Tabs>
          {pages.map(([mode, title]) => (
            <Tabs.Tab
              key={mode}
              selected={data.mode === mode}
              onClick={() => act('page', { mode: String(mode) })}
            >
              &gt; {title}
            </Tabs.Tab>
          ))}
        </Tabs>
        <Box className="MS13Terminal__page">
          {data.mode === 0 && (
            <Section
              title="Documents"
              buttons={
                data.notekeeper && (
                  <Button icon="pen" onClick={() => act('page', { mode: '1' })}>
                    Write entry
                  </Button>
                )
              }
            >
              {data.documents.map((doc) => (
                <Button
                  key={doc.choice}
                  fluid
                  icon="file-alt"
                  onClick={() => legacy(doc.choice)}
                >
                  {doc.title}
                </Button>
              ))}
              {!data.documents.length && (
                <Box color="label">No documents stored.</Box>
              )}
              {!!data.riggedTitle && (
                <Button fluid onClick={() => legacy('joker')}>
                  {data.riggedTitle}
                </Button>
              )}
            </Section>
          )}
          {(data.mode === 1 || data.mode === 2) && (
            <Section
              title={data.title || 'Untitled entry'}
              buttons={
                data.mode === 1 && (
                  <>
                    <Button onClick={() => legacy('Title')}>Title</Button>
                    <Button onClick={() => legacy('Contents')}>Edit</Button>
                    <Button icon="save" onClick={() => legacy('Save')}>
                      Save
                    </Button>
                  </>
                )
              }
            >
              <Box
                style={{ whiteSpace: 'pre-wrap' }}
                dangerouslySetInnerHTML={{
                  __html: sanitizeText(data.content || ''),
                }}
              />
            </Section>
          )}
          {data.mode === 3 && (
            <Section title="Connected circuits">
              {data.signals.map((signal) => (
                <Button
                  key={signal.choice}
                  fluid
                  icon="power-off"
                  onClick={() => legacy(signal.choice)}
                >
                  {signal.title}
                </Button>
              ))}
              {!data.signals.length && (
                <Box color="label">No mapped circuits.</Box>
              )}
            </Section>
          )}
          {data.mode === 5 && (
            <>
              {!!data.command && (
                <SquadPanel
                  data={data.command}
                  act={(command, params = {}) =>
                    act('command', { command, ...params })
                  }
                />
              )}
              <Section title="Available personnel">
                <Flex wrap="wrap">
                  {data.recruits.map((unit) => (
                    <Flex.Item key={unit.ref} mr={1} mb={1}>
                      <Button
                        icon="user-plus"
                        onClick={() => legacy('squad', { recruit: unit.ref })}
                      >
                        {unit.name} • {unit.squad || 'Recruit'}
                      </Button>
                    </Flex.Item>
                  ))}
                </Flex>
                {!data.recruits.length && (
                  <NoticeBox>
                    No linked personnel. Bring an unassigned recruit within
                    seven tiles.
                  </NoticeBox>
                )}
              </Section>
            </>
          )}
          {data.mode === 6 && (
            <Section
              title="Cryogenic storage"
              buttons={
                <Button
                  icon="play"
                  onClick={() => legacy('cryo_wake', { pod: 'all' })}
                >
                  Wake all ready pods
                </Button>
              }
            >
              {data.pods.map((pod) => (
                <Section
                  key={pod.ref}
                  title={pod.name}
                  buttons={
                    <Button
                      disabled={!pod.ready}
                      icon="play"
                      onClick={() => legacy('cryo_wake', { pod: pod.ref })}
                    >
                      Wake occupant
                    </Button>
                  }
                >
                  <Box color={pod.ready ? 'good' : 'label'}>
                    {pod.status} • {pod.position}
                  </Box>
                </Section>
              ))}
              {!data.pods.length && (
                <NoticeBox>No nearby or network-linked cryopods.</NoticeBox>
              )}
            </Section>
          )}
          {(data.mode === 7 || data.mode === 8) && data.camera && (
            <Flex height="100%" className="MS13Terminal__camera">
              <Flex.Item width="180px" mr={1} shrink={0}>
                <Section title="Feeds" fill scrollable>
                  {data.camera.cameras.map((camera) => (
                    <Button
                      key={camera.name}
                      fluid
                      icon="video"
                      selected={data.camera.activeCamera?.name === camera.name}
                      onClick={() =>
                        act('switch_camera', { name: camera.name })
                      }
                    >
                      {camera.name}
                    </Button>
                  ))}
                  {!data.camera.cameras.length && (
                    <Box color="label">
                      No cameras paired. Tap a held bodycam on this terminal,
                      then attach it to clothing.
                    </Box>
                  )}
                </Section>
              </Flex.Item>
              <Flex.Item grow style={{ minWidth: 0 }}>
                <Section
                  title={
                    data.camera.activeCamera
                      ? `${data.camera.activeCamera.name}${data.camera.online ? '' : ' — Offline'}`
                      : 'Select a camera'
                  }
                  fill
                >
                  <ByondUi
                    key={data.camera.mapRef}
                    style={{ width: '100%', height: '100%' }}
                    params={{ id: data.camera.mapRef, type: 'map' }}
                  />
                </Section>
              </Flex.Item>
            </Flex>
          )}
          {data.mode === 4 && (
            <>
              <Section
                title={`Work queue • ${data.queue.length}/20`}
                buttons={
                  <>
                    <Button
                      icon="play"
                      disabled={
                        data.running || !data.queue.length || !data.canManage
                      }
                      onClick={() => legacy('workshop_start')}
                    >
                      Start / Resume
                    </Button>
                    <Button
                      icon="stop"
                      disabled={!data.canManage}
                      onClick={() => legacy('workshop_stop')}
                    >
                      Stop / Clear
                    </Button>
                  </>
                }
              >
                <NoticeBox>{data.workshopStatus}</NoticeBox>
                {data.queue.map((name, index) => (
                  <Box key={index}>
                    {index + 1}. {name}
                  </Box>
                ))}
              </Section>
              <Input
                fluid
                placeholder="Search connected recipes…"
                value={search}
                onInput={(event, value) => setSearch(value)}
              />
              {data.benches.map((bench) => (
                <Section key={bench.ref} title={bench.name}>
                  {!!bench.armor && (
                    <Box>
                      {bench.armor}
                      <br />
                      Cell: {bench.cell}
                      {bench.parts.map((part) => (
                        <Box key={part}>{part}</Box>
                      ))}
                    </Box>
                  )}
                  {bench.hoist ? (
                    <Button
                      icon="wrench"
                      onClick={() =>
                        legacy('workshop_hoist', { bench: bench.ref })
                      }
                    >
                      {bench.mounted ? 'Release armor' : 'Mount armor'}
                    </Button>
                  ) : (
                    bench.recipes
                      .filter((recipe) =>
                        recipe.name
                          .toLowerCase()
                          .includes(search.toLowerCase()),
                      )
                      .map((recipe) => (
                        <Section
                          key={recipe.ref}
                          title={recipe.name}
                          buttons={
                            <Button
                              icon="plus"
                              disabled={
                                !data.canManage || data.queue.length >= 20
                              }
                              onClick={() =>
                                legacy('workshop_queue', {
                                  bench: bench.ref,
                                  recipe: recipe.ref,
                                })
                              }
                            >
                              Queue
                            </Button>
                          }
                        >
                          <Box>Materials: {recipe.materials}</Box>
                          {!!recipe.tools && (
                            <Box color="label">Tools: {recipe.tools}</Box>
                          )}
                          {!!recipe.catalysts && (
                            <Box color="label">
                              Catalysts: {recipe.catalysts}
                            </Box>
                          )}
                        </Section>
                      ))
                  )}
                </Section>
              ))}
              {!data.benches.length && (
                <NoticeBox>
                  Place a workbench, chemistry set, or armor hoist beside this
                  terminal.
                </NoticeBox>
              )}
            </>
          )}
        </Box>
      </Window.Content>
    </Window>
  );
};
