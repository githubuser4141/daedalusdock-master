import '../styles/interfaces/MS13Terminal.scss';

import { useBackend, useLocalState } from '../backend';
import {
  Box,
  Button,
  ByondUi,
  Dropdown,
  Flex,
  Input,
  NoticeBox,
  Section,
} from '../components';
import { Window } from '../layouts';
import { sanitizeText } from '../sanitize';
import { SquadPanel } from './MS13Squad';

export const MS13Terminal = () => {
  const { data, act } = useBackend();
  const [search, setSearch] = useLocalState('recipes', '');
  const legacy = (choice, params = {}) => act('legacy', { choice, ...params });
  const page = (mode) => act('page', { mode: String(mode) });
  const cameraPage = data.mode === 7 || data.mode === 8;
  const command = (command, params = {}) =>
    act('command', { command, ...params });
  const titles = {
    0: `${data.terminalTag} Terminal ${data.terminalNumber}`,
    1: 'RobCo Word Processor V.22',
    2: data.title || 'Untitled entry',
    3: 'RobCo Utili-Dock V.5',
    4: 'RobCo Workshop',
    5: 'Squad command',
    6: 'Cryopod control',
    7: 'Body cameras',
    8: 'Security cameras',
  };
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
          <Box>{`= ${titles[data.mode]} =`}</Box>
        </Box>
        <Box
          className={`MS13Terminal__page${cameraPage ? ' MS13Terminal__page--camera' : ''}`}
        >
          {data.mode === 0 && (
            <>
              <Box>TERMINAL FUNCTIONS</Box>
              <Box className="MS13Terminal__menu">
                {!!data.notekeeper && (
                  <Button onClick={() => page(1)}>&gt; Word Processor</Button>
                )}
                {!!data.remote && (
                  <Button onClick={() => page(3)}>&gt; Utili-Dock</Button>
                )}
                <Button onClick={() => page(4)}>&gt; Workshop</Button>
                <Button onClick={() => page(5)}>&gt; Squad command</Button>
                <Button onClick={() => page(6)}>&gt; Cryopod control</Button>
                <Button onClick={() => page(7)}>&gt; Body cameras</Button>
              </Box>
              <Box mt={2}>FILE SYSTEM</Box>
              <Box className="MS13Terminal__menu">
                {data.documents.map((doc) => (
                  <Button key={doc.choice} onClick={() => legacy(doc.choice)}>
                    &gt; {doc.title}
                  </Button>
                ))}
                {!data.documents.length && (
                  <Box color="label">No documents stored.</Box>
                )}
                {!!data.riggedTitle && (
                  <Button onClick={() => legacy('joker')}>
                    &gt; {data.riggedTitle}
                  </Button>
                )}
              </Box>
            </>
          )}
          {(data.mode === 1 || data.mode === 2) && (
            <>
              {data.mode === 1 && (
                <Box mb={1}>{data.title || 'Untitled entry'}</Box>
              )}
              <Box
                style={{ whiteSpace: 'pre-wrap' }}
                dangerouslySetInnerHTML={{
                  __html: sanitizeText(data.content || ''),
                }}
              />
            </>
          )}
          {data.mode === 3 && (
            <Box className="MS13Terminal__menu">
              <Box>Network online. Select a linked circuit.</Box>
              {!!data.security && (
                <Button onClick={() => page(8)}>&gt; Security cameras</Button>
              )}
              {data.signals.map((signal) => (
                <Button
                  key={signal.choice}
                  onClick={() => legacy(signal.choice)}
                >
                  &gt; {signal.title}
                </Button>
              ))}
              {!data.signals.length && (
                <Box color="label">No mapped circuits.</Box>
              )}
            </Box>
          )}
          {data.mode === 5 && (
            <>
              {!!data.command && (
                <SquadPanel data={data.command} act={command} />
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
          {cameraPage && data.camera && (
            <Box className="MS13Terminal__camera">
              <Box mb={1}>
                Feed:{' '}
                <Dropdown
                  width="240px"
                  options={data.camera.cameras.map((camera) => camera.name)}
                  selected={data.camera.activeCamera?.name}
                  placeholder="Select a camera"
                  onSelected={(name) => act('switch_camera', { name })}
                />{' '}
                {data.camera.online ? 'ONLINE' : 'NO SIGNAL'}
              </Box>
              <Flex grow className="MS13Terminal__cameraBody">
                <Flex.Item grow className="MS13Terminal__feed">
                  <ByondUi
                    className="MS13Terminal__map"
                    key={data.camera.mapRef}
                    style={{ width: '100%', height: '100%' }}
                    params={{ id: data.camera.mapRef, type: 'map' }}
                  />
                </Flex.Item>
                <Flex.Item
                  width="340px"
                  ml={1}
                  shrink={0}
                  className="MS13Terminal__command"
                >
                  {data.command ? (
                    <SquadPanel data={data.command} act={command} />
                  ) : (
                    <>
                      <Box mb={1}>SQUAD COMMAND</Box>
                      <Box mb={1}>
                        Take command of linked personnel to issue orders through
                        this feed.
                      </Box>
                      {data.recruits.map((unit) => (
                        <Button
                          key={unit.ref}
                          fluid
                          onClick={() => legacy('squad', { recruit: unit.ref })}
                        >
                          &gt; {unit.name}
                        </Button>
                      ))}
                      {!data.recruits.length && <Box>No linked personnel.</Box>}
                    </>
                  )}
                  {!data.camera.cameras.length && (
                    <Box mt={2}>
                      Tap a held bodycam on this terminal, then attach it to
                      clothing.
                    </Box>
                  )}
                </Flex.Item>
              </Flex>
            </Box>
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
        {!!data.mode && (
          <Box className="MS13Terminal__footer">
            {data.mode === 1 && (
              <>
                <Button onClick={() => legacy('Title')}>&gt; Title</Button>
                <Button onClick={() => legacy('Contents')}>
                  &gt; Edit contents
                </Button>
                <Button onClick={() => legacy('Save')}>&gt; Save</Button>
              </>
            )}
            <Button onClick={() => page(0)}>&gt; Return</Button>
          </Box>
        )}
      </Window.Content>
    </Window>
  );
};
