import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Dimmer,
  Icon,
  NoticeBox,
  Section,
  Stack,
} from '../components';
import { Window } from '../layouts';

type Stop = {
  name: string;
  ref: string;
  x: number;
  y: number;
};

type Data = {
  destination: string | null;
  location: string | null;
  moving: boolean;
  powered: boolean;
  rails: [number, number][];
  stops: Stop[];
  train: [number, number] | null;
};

/** Board drawing units along its longest side; markers and text are sized in these. */
const BOARD = 600;
/** Tiles of margin around the line. */
const PAD = 4;

const COLORS = {
  ground: '#1b1206',
  rail: '#fda751',
  stop: '#ffe3b8',
  picked: '#7ee06a',
  train: '#6ec6ff',
};

const isHere = (stop: Stop, train: Data['train']) =>
  !!train && stop.x === train[0] && stop.y === train[1];

type BoardProps = {
  data: Data;
  onPick: (ref: string) => void;
  picked: string | null;
};

const Board = (props: BoardProps) => {
  const { data, picked, onPick } = props;
  const { rails, stops, train, destination } = data;
  if (!rails.length) {
    return <NoticeBox>This car is not sitting on a rail line.</NoticeBox>;
  }
  const xs = rails.map((rail) => rail[0]);
  const ys = rails.map((rail) => rail[1]);
  const minX = Math.min(...xs) - PAD;
  const maxX = Math.max(...xs) + PAD;
  const minY = Math.min(...ys) - PAD;
  const maxY = Math.max(...ys) + PAD;
  const scale = BOARD / Math.max(maxX - minX, maxY - minY);
  const width = (maxX - minX) * scale;
  const height = (maxY - minY) * scale;
  const px = (x: number) => (x - minX) * scale;
  // North is up on the board.
  const py = (y: number) => (maxY - y) * scale;

  // One path joining every pair of neighbouring rails.
  const laid = new Set(rails.map(([x, y]) => `${x},${y}`));
  let line = '';
  for (const [x, y] of rails) {
    if (laid.has(`${x + 1},${y}`)) {
      line += `M${px(x)} ${py(y)}H${px(x + 1)}`;
    }
    if (laid.has(`${x},${y + 1}`)) {
      line += `M${px(x)} ${py(y)}V${py(y + 1)}`;
    }
  }

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      width="100%"
      height="100%"
      preserveAspectRatio="xMidYMid meet"
      style={{ background: COLORS.ground, borderRadius: '4px' }}
    >
      <path
        d={line}
        stroke={COLORS.rail}
        strokeWidth={6}
        strokeLinecap="round"
        fill="none"
      />
      {stops.map((stop) => {
        const chosen = stop.ref === (picked ?? destination);
        const x = px(stop.x);
        const y = py(stop.y);
        // Labels near the right edge go on the left, so they stay on the board.
        const leftLabel = x > width * 0.7;
        return (
          <g
            key={stop.ref}
            onClick={() => onPick(stop.ref)}
            style={{ cursor: 'pointer' }}
          >
            <title>{stop.name}</title>
            <circle
              cx={x}
              cy={y}
              r={chosen ? 13 : 9}
              fill={chosen ? COLORS.picked : COLORS.stop}
              stroke={COLORS.ground}
              strokeWidth={4}
            />
            <text
              x={leftLabel ? x - 18 : x + 18}
              y={y + 6}
              textAnchor={leftLabel ? 'end' : 'start'}
              fontSize={18}
              fontWeight={chosen ? 'bold' : 'normal'}
              fill={chosen ? COLORS.picked : COLORS.stop}
              stroke={COLORS.ground}
              strokeWidth={5}
              paintOrder="stroke"
            >
              {stop.name}
            </text>
          </g>
        );
      })}
      {train && (
        <g>
          <title>This car</title>
          <circle
            cx={px(train[0])}
            cy={py(train[1])}
            r={16}
            fill="none"
            stroke={COLORS.train}
            strokeWidth={4}
          />
          <circle
            cx={px(train[0])}
            cy={py(train[1])}
            r={7}
            fill={COLORS.train}
          />
        </g>
      )}
    </svg>
  );
};

const Legend = () => (
  <Stack justify="center" fontSize="11px">
    <Stack.Item>
      <Icon name="circle" color={COLORS.stop} /> Stop
    </Stack.Item>
    <Stack.Item>
      <Icon name="circle" color={COLORS.picked} /> Chosen stop
    </Stack.Item>
    <Stack.Item>
      <Icon name="dot-circle" color={COLORS.train} /> This car
    </Stack.Item>
  </Stack>
);

export const RailTerminal = (props) => {
  const { act, data } = useBackend<Data>();
  const { stops, powered, moving, train, location, destination } = data;
  const [picked, setPicked] = useState<string | null>(null);

  const here = stops.find((stop) => isHere(stop, train));
  const heading = stops.find((stop) => stop.ref === destination);
  const choice = stops.find((stop) => stop.ref === picked);
  const sorted = [...stops].sort((a, b) => a.name.localeCompare(b.name));

  let status = 'Not on the line';
  if (moving && heading) {
    status = `On the way to ${heading.name}`;
  } else if (moving) {
    status = 'Moving';
  } else if (here) {
    status = `Stopped at ${here.name}`;
  } else if (location) {
    status = `Stopped near ${location}`;
  }

  return (
    <Window theme="retro-dark" width={780} height={500}>
      <Window.Content>
        {!powered && (
          <Dimmer fontSize="16px">
            <Icon name="car-battery" mr={1} />
            No power. Check the car&apos;s battery.
          </Dimmer>
        )}
        <Stack fill>
          <Stack.Item grow>
            <Section fill title="Line map">
              <Stack vertical fill>
                <Stack.Item grow>
                  <Board data={data} picked={picked} onPick={setPicked} />
                </Stack.Item>
                <Stack.Item>
                  <Legend />
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
          <Stack.Item basis="250px">
            <Stack vertical fill>
              <Stack.Item>
                <Section title="Status">
                  <Box bold fontSize="14px">
                    <Icon
                      name={moving ? 'train' : 'pause-circle'}
                      mr={1}
                      color={moving ? 'good' : 'label'}
                    />
                    {status}
                  </Box>
                </Section>
              </Stack.Item>
              <Stack.Item grow>
                <Section fill scrollable title="Stops">
                  {!sorted.length && (
                    <Box color="label">No stops on this line.</Box>
                  )}
                  {sorted.map((stop) => (
                    <Button
                      key={stop.ref}
                      fluid
                      ellipsis
                      icon={
                        isHere(stop, train)
                          ? 'map-marker-alt'
                          : stop.ref === destination
                            ? 'flag-checkered'
                            : 'circle'
                      }
                      selected={stop.ref === picked}
                      tooltip={isHere(stop, train) ? 'You are here' : null}
                      onClick={() => setPicked(stop.ref)}
                    >
                      {stop.name}
                    </Button>
                  ))}
                </Section>
              </Stack.Item>
              <Stack.Item>
                <Button
                  fluid
                  textAlign="center"
                  fontSize="14px"
                  icon="play"
                  color="good"
                  disabled={!choice || moving || isHere(choice, train)}
                  onClick={() => act('depart', { stop: picked })}
                >
                  {choice ? `Depart for ${choice.name}` : 'Pick a stop'}
                </Button>
                <Button
                  fluid
                  textAlign="center"
                  icon="hand-paper"
                  color="caution"
                  disabled={!moving}
                  onClick={() => act('halt')}
                >
                  Emergency stop
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
