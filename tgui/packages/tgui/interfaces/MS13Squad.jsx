import { useBackend } from '../backend';
import { Box, Button, Flex, NoticeBox, Section, Table } from '../components';
import { Window } from '../layouts';

const icons = {
  Move: 'location-arrow',
  Guard: 'shield-alt',
  Follow: 'walking',
  Patrol: 'route',
  Attack: 'crosshairs',
  'Fire at area': 'bullseye',
  'Fire direction': 'arrows-alt',
  Use: 'hand-pointer',
  Sit: 'chair',
  Destroy: 'hammer',
  Breach: 'bomb',
  'Pick up': 'hand-paper',
  Deliver: 'box',
  Hold: 'stop',
};
const individual = ['Use', 'Sit', 'Pick up', 'Deliver'];
const instructions = {
  Move: 'Move onto the selected tile, then guard there.',
  Guard: 'Take up a position and engage nearby hostiles.',
  Follow: 'Follow the commander or a squadmate, including stairs.',
  Patrol: 'Travel between the current position and the selected tile.',
  Attack:
    'Engage an enemy, or breach an obstacle using the selected breach method.',
  'Fire at area':
    'Suppress a visible area from the current position. Live fire can hit bystanders.',
  'Fire direction':
    'Fire toward the selected direction from the current position.',
  Use: 'Operate one button or door. Normal locks, access and power apply.',
  Sit: 'Board a vehicle and buckle into the selected empty seat.',
  Destroy: 'Break a wall, structure or machine with carried melee tools.',
  Breach:
    'Assign one recruit to clear an obstacle using the selected method. Explosives require a carried charge, friendly clearance and an escape route.',
  'Pick up':
    'Collect a loose item. Requires a free hand and sufficient carrying ability.',
  Deliver: 'Carry the last collected item onto the selected tile and drop it.',
  Hold: 'Cancel the current order and stop. Still defends against attacks and escapes live charges.',
};

export const SquadPanel = ({ data, act }) => (
  <>
    <Section
      title={data.squad || 'Squad command'}
      buttons={
        <Button icon="sign-out-alt" color="bad" onClick={() => act('release')}>
          Release command
        </Button>
      }
    >
      <Button
        fluid
        selected={data.selected === 'all'}
        icon="users"
        onClick={() => act('unit', { value: 'all' })}
      >
        Entire squad
      </Button>
      <Table mt={1}>
        <Table.Row header>
          <Table.Cell>Unit</Table.Cell>
          <Table.Cell>Assignment</Table.Cell>
          <Table.Cell>Status</Table.Cell>
        </Table.Row>
        {(data.units || []).map((unit) => (
          <Table.Row key={unit.ref}>
            <Table.Cell>
              <Button
                fluid
                selected={data.selected === unit.ref}
                icon="user"
                onClick={() => act('unit', { value: unit.ref })}
              >
                {unit.name}
              </Button>
              <Box color="label" fontSize="0.85em">
                {unit.position}
              </Box>
            </Table.Cell>
            <Table.Cell>
              {unit.order}
              <Box color="label">{unit.fireMode}</Box>
              <Box color="label">Breach: {unit.breachMode}</Box>
            </Table.Cell>
            <Table.Cell color={unit.ready ? 'good' : 'average'}>
              {unit.ready ? unit.status : 'Unavailable'}
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
    </Section>
    {data.designating && (
      <NoticeBox info>
        <Flex align="center">
          <Flex.Item grow>
            Click a target in the world or camera feed for <b>{data.pending}</b>
            . Right-click cancels.
          </Flex.Item>
          <Flex.Item>
            <Button icon="times" onClick={() => act('cancel')}>
              Cancel
            </Button>
          </Flex.Item>
        </Flex>
      </NoticeBox>
    )}
    <Section title="Orders">
      {data.selected === 'all' && (
        <Box mb={1} color="label">
          Select one unit for item handling, doors, and seats.
        </Box>
      )}
      <Flex wrap="wrap">
        {(data.orders || []).map((order) => (
          <Flex.Item key={order} basis="32%" mr={0.5} mb={0.5}>
            <Button
              fluid
              icon={icons[order]}
              tooltip={instructions[order]}
              color={
                order === 'Breach' || order === 'Destroy'
                  ? 'average'
                  : undefined
              }
              selected={data.designating && data.pending === order}
              disabled={data.selected === 'all' && individual.includes(order)}
              onClick={() => act('order', { value: order })}
            >
              {order}
            </Button>
          </Flex.Item>
        ))}
      </Flex>
      <Box mt={1} color="label">
        Destroy uses melee tools. Breach follows your selected method. When a
        charge is used, keep clear of the announced blast radius. A live charge
        keeps its fuse if orders change.
      </Box>
      {data.terminal &&
        [
          'Move',
          'Guard',
          'Patrol',
          'Fire at area',
          'Fire direction',
          'Deliver',
        ].includes(data.pending) && (
          <Button
            mt={1}
            icon="map-marker-alt"
            onClick={() => act('coordinates')}
          >
            Designate {data.pending.toLowerCase()} by coordinates
          </Button>
        )}
    </Section>
    <Section title="Breach method">
      {(data.breachModes || []).map((mode) => (
        <Button
          key={mode}
          selected={(data.units || [])
            .filter(
              (unit) => data.selected === 'all' || data.selected === unit.ref,
            )
            .every((unit) => unit.breachMode === mode)}
          onClick={() => act('breach_mode', { value: mode })}
        >
          {mode}
        </Button>
      ))}
      <Box mt={1} color="label">
        Auto tries an effective melee tool, then a gun, then a carried charge.
        Normal armor, ammunition, and explosive safety still apply.
      </Box>
    </Section>
    <Section title="Fire discipline">
      {(data.fireModes || []).map((mode) => (
        <Button
          key={mode}
          icon="crosshairs"
          tooltip={
            {
              Careful: 'Spaced shots with a clear lane.',
              Precise: 'Stop, aim, and wait for recoil to settle.',
              Rapid: 'Fire as quickly as the weapon permits.',
            }[mode]
          }
          onClick={() => act('fire_mode', { value: mode })}
        >
          {mode}
        </Button>
      ))}
      <Box mt={1} color="label">
        Units defend against hostiles, recover their dropped firearm, and use
        available light. Ammunition and injuries still matter.
      </Box>
    </Section>
  </>
);

export const MS13Squad = () => {
  const { data, act } = useBackend();
  return (
    <Window width={560} height={480} title="Squad command" theme="mojavesun">
      <Window.Content scrollable>
        <SquadPanel data={data} act={act} />
      </Window.Content>
    </Window>
  );
};
