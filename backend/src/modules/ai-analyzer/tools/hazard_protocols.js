// Plain-language protocol text for the hazard analysis. No invented regulation numbers; mines must follow their own statutory procedures.
export const HAZARD_PROTOCOLS = {
  GAS_LEAK: {
    immediateActions: ['Withdraw everyone from the affected area to fresh intake air', 'Do not switch electrical equipment on or off', 'Inform the ventilation officer and the control room immediately', 'Use self-rescuers if CO or smoke is present'],
    doNot: ['Do not create any ignition source', 'Do not re-enter until gas testing is done'],
    notify: ['Ventilation officer', 'Shift in-charge', 'Control room'],
  },
  FIRE_SMOKE: {
    immediateActions: ['Raise the alarm and tell the control room', 'Put on self-rescuers and move to fresh intake air', 'Follow the nearest evacuation route away from the smoke'],
    doNot: ['Do not try to fight a large fire', 'Do not isolate power unless you are authorised to'],
    notify: ['Control room', 'Mine rescue station', 'Shift in-charge'],
  },
  FLOODING: {
    immediateActions: ['Move people to higher ground away from the water', 'Warn others and inform the control room', 'Keep clear of electrical equipment in the water'],
    doNot: ['Do not cross moving or deep water', 'Do not restart pumps unless authorised'],
    notify: ['Control room', 'Pump operator', 'Shift in-charge'],
  },
  ROOF_FALL: {
    immediateActions: ['Withdraw everyone from the affected area and keep a safe distance', 'Account for all workers and report anyone trapped', 'Inform the control room and the geotechnical in-charge'],
    doNot: ['Do not walk under unsupported roof', 'Do not start clearing before the roof is made safe'],
    notify: ['Control room', 'Mining sirdar', 'Mine rescue station if people are trapped'],
  },
  ELECTRICAL: {
    immediateActions: ['Do not touch the cable or equipment', 'Keep everyone at least 3 m away', 'Have an authorised electrician isolate the supply'],
    doNot: ['Do not use water on electrical fires', 'Do not touch a person in contact with live equipment'],
    notify: ['Authorised electrician', 'Shift in-charge'],
  },
  EQUIPMENT_FAILURE: {
    immediateActions: ['Stop the equipment and apply lock-out / tag-out', 'Keep people clear of moving or stored energy', 'Report the fault to the shift in-charge'],
    doNot: ['Do not bypass guards or interlocks', 'Do not restart before it is inspected'],
    notify: ['Shift in-charge', 'Maintenance fitter'],
  },
  VENTILATION_FAILURE: {
    immediateActions: ['Withdraw people from areas with poor airflow', 'Check gas levels with a calibrated detector before entry', 'Inform the ventilation officer'],
    doNot: ['Do not continue work where airflow has stopped'],
    notify: ['Ventilation officer', 'Control room'],
  },
  OTHER: {
    immediateActions: ['Keep people away from the hazard', 'Report it to the shift in-charge', 'Mark off the area'],
    doNot: ['Do not attempt a repair unless you are authorised'],
    notify: ['Shift in-charge'],
  },
};

export function getHazardProtocol(category) {
  const p = HAZARD_PROTOCOLS[category] ?? HAZARD_PROTOCOLS.OTHER;
  return { status: 'ok', category: HAZARD_PROTOCOLS[category] ? category : 'OTHER', ...p };
}
