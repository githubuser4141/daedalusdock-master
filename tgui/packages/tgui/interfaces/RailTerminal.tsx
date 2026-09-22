import { CSSProperties, useEffect, useMemo, useRef, useState } from 'react';

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

/** Board x, y and level: 0 is the car's level when the board was drawn, above and below count up and down. */
type Spot = [number, number, number];

type Stop = {
  level: number;
  name: string;
  ref: string;
  x: number;
  y: number;
};

type Data = {
  automated: boolean;
  destination: string | null;
  fitted: boolean;
  halting: boolean;
  links: [...Spot, ...Spot][];
  location: string | null;
  moving: boolean;
  powered: boolean;
  rails: Spot[];
  stops: Stop[];
  train: Spot | null;
};

/** Pixels kept clear around the line, so markers and labels at its ends stay on the board. */
const MARGIN = 32;
/** Most pixels a tile may take, so a short line isn't blown up to fill the board. */
const MAX_TILE = 24;

const COLORS = {
  ground: '#1b1206',
  rail: '#fda751',
  stop: '#ffe3b8',
  picked: '#7ee06a',
  train: '#6ec6ff',
};

const isHere = (stop: Stop, train: Data['train']) =>
  !!train &&
  stop.x === train[0] &&
  stop.y === train[1] &&
  stop.level === train[2];

/** Line on the car's own level is solid; on others it is dashed and dimmer. */
const lineStyle = (level: number) =>
  level ? { strokeDasharray: '8 6', opacity: 0.55 } : {};

type BoardProps = {
  data: Data;
  onPick: (ref: string) => void;
  picked: string | null;
};

/** Fits the line to a board of this size, north up, and draws its paths: one per level, and the joins between. */
const drawLine = (
  rails: Spot[],
  links: Data['links'],
  width: number,
  height: number,
) => {
  let minX = Infinity;
  let maxX = -Infinity;
  let minY = Infinity;
  let maxY = -Infinity;
  for (const [x, y] of rails) {
    minX = Math.min(minX, x);
    maxX = Math.max(maxX, x);
    minY = Math.min(minY, y);
    maxY = Math.max(maxY, y);
  }
  const scale = Math.max(
    Math.min(
      (width - 2 * MARGIN) / Math.max(maxX - minX, 1),
      (height - 2 * MARGIN) / Math.max(maxY - minY, 1),
      MAX_TILE,
    ),
    0.01,
  );
  const left = (width - (maxX - minX) * scale) / 2;
  const top = (height - (maxY - minY) * scale) / 2;
  const px = (x: number) => left + (x - minX) * scale;
  const py = (y: number) => top + (maxY - y) * scale;
  const laid = new Set(rails.map((spot) => spot.join()));
  const lines: Record<number, string> = {};
  for (const [x, y, level] of rails) {
    let line = lines[level] || '';
    if (laid.has([x + 1, y, level].join())) {
      line += `M${px(x)} ${py(y)}H${px(x + 1)}`;
    }
    if (laid.has([x, y + 1, level].join())) {
      line += `M${px(x)} ${py(y)}V${py(y + 1)}`;
    }
    lines[level] = line;
  }
  // Inclines up and down, and region crossings.
  let joins = '';
  for (const [x1, y1, , x2, y2] of links) {
    joins += `M${px(x1)} ${py(y1)}L${px(x2)} ${py(y2)}`;
  }
  // Farthest levels first, so the car's own is drawn on top.
  const levels = Object.keys(lines)
    .map(Number)
    .sort((a, b) => Math.abs(b) - Math.abs(a));
  return { px, py, lines, joins, levels };
};

/**
 * The line map, drawn in pixels to fit whatever room its (relatively positioned) parent gives it, so markers and
 * labels keep their size in a small window. It measures that room itself: an SVG left to size itself grows to its
 * picture's shape, and a long thin line pushes it off the board.
 */
const Board = (props: BoardProps) => {
  const { data, picked, onPick } = props;
  const { train, destination } = data;
  const rails = data.rails || [];
  const stops = data.stops || [];
  const box = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ width: 0, height: 0 });
  useEffect(() => {
    const measure = () =>
      box.current &&
      setSize({
        width: box.current.clientWidth,
        height: box.current.clientHeight,
      });
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  }, []);
  const { width, height } = size;
  const filled: CSSProperties = {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    right: 0,
  };
  // The rails never change while the board is open; only the car moves across them.
  const drawing = useMemo(
    () =>
      rails.length && width && height
        ? drawLine(rails, data.links || [], width, height)
        : null,
    [rails, data.links, width, height],
  );
  if (!drawing) {
    return (
      <div ref={box} style={filled}>
        {!rails.length && (
          <NoticeBox>This car is not sitting on a rail line.</NoticeBox>
        )}
      </div>
    );
  }
  const { px, py, lines, joins, levels } = drawing;

  return (
    <div ref={box} style={filled}>
      <svg
        width={width}
        height={height}
        style={{
          display: 'block',
          background: COLORS.ground,
          borderRadius: '4px',
        }}
      >
        {levels.map((level) => (
          <path
            key={level}
            d={lines[level]}
            stroke={COLORS.rail}
            strokeWidth={4}
            strokeLinecap="round"
            fill="none"
            {...lineStyle(level)}
          />
        ))}
        <path
          d={joins}
          stroke={COLORS.rail}
          strokeWidth={4}
          strokeLinecap="round"
          fill="none"
          strokeDasharray="2 6"
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
              <title>
                {stop.name}
                {stop.level > 0 && ' (level above)'}
                {stop.level < 0 && ' (level below)'}
              </title>
              <circle
                cx={x}
                cy={y}
                r={chosen ? 9 : 6}
                fill={chosen ? COLORS.picked : COLORS.stop}
                stroke={COLORS.ground}
                strokeWidth={3}
              />
              <text
                x={leftLabel ? x - 12 : x + 12}
                y={y + 4}
                textAnchor={leftLabel ? 'end' : 'start'}
                fontSize={13}
                fontWeight={chosen ? 'bold' : 'normal'}
                fill={chosen ? COLORS.picked : COLORS.stop}
                stroke={COLORS.ground}
                strokeWidth={4}
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
              r={11}
              fill="none"
              stroke={COLORS.train}
              strokeWidth={3}
            />
            <circle
              cx={px(train[0])}
              cy={py(train[1])}
              r={4}
              fill={COLORS.train}
            />
          </g>
        )}
      </svg>
    </div>
  );
};

const Legend = (props: { levels: boolean }) => (
  <Stack justify="center" wrap fontSize="11px">
    <Stack.Item>
      <Icon name="circle" color={COLORS.stop} /> Stop
    </Stack.Item>
    <Stack.Item>
      <Icon name="circle" color={COLORS.picked} /> Chosen stop
    </Stack.Item>
    <Stack.Item>
      <Icon name="dot-circle" color={COLORS.train} /> This car
    </Stack.Item>
    {props.levels && (
      <Stack.Item>
        <Icon name="ellipsis-h" color={COLORS.rail} /> Line on another level
      </Stack.Item>
    )}
  </Stack>
);

export const RailTerminal = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    automated,
    fitted,
    halting,
    moving,
    powered,
    train,
    location,
    destination,
  } = data;
  const stops = data.stops || [];
  const [picked, setPicked] = useState<string | null>(null);

  const here = stops.find((stop) => isHere(stop, train));
  const heading = stops.find((stop) => stop.ref === destination);
  const choice = stops.find((stop) => stop.ref === picked);
  const sorted = [...stops].sort((a, b) => a.name.localeCompare(b.name));

  let status = 'Not on the line';
  if (halting) {
    status = 'Braking to a stop';
  } else if (automated && moving && heading) {
    status = `On service to ${heading.name}`;
  } else if (automated && here) {
    status = `On service, calling at ${here.name}`;
  } else if (moving && heading) {
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
        {!fitted && (
          <Dimmer fontSize="16px">
            <Icon name="unlink" mr={1} />
            Not fitted to a rail car. Build or place it on one.
          </Dimmer>
        )}
        {!!fitted && !powered && (
          <Dimmer fontSize="16px">
            <Icon name="car-battery" mr={1} />
            No power. Check the car&apos;s battery.
          </Dimmer>
        )}
        <Stack fill>
          <Stack.Item grow>
            <Section fill title="Line map">
              <Stack vertical fill>
                <Stack.Item grow position="relative">
                  <Board data={data} picked={picked} onPick={setPicked} />
                </Stack.Item>
                <Stack.Item>
                  <Legend levels={(data.rails || []).some((spot) => spot[2])} />
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
          <Stack.Item basis="32%" minWidth="150px" maxWidth="260px">
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
                  ellipsis
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
                  disabled={!moving || halting}
                  onClick={() => act('halt')}
                >
                  Emergency stop
                </Button>
                <Button
                  fluid
                  textAlign="center"
                  icon="sync"
                  selected={automated}
                  tooltip="Calls at every stop on the line in turn, waiting at each with the doors open."
                  onClick={() => act('automate')}
                >
                  {automated
                    ? 'Automatic service: on'
                    : 'Automatic service: off'}
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
