import 'package:flutter/material.dart' show IconData, Icons;

/// First-aid guides as Dart constants (no asset files) so they work with no connection.
class FirstAidGuide {
  const FirstAidGuide({required this.title, required this.icon, required this.steps});
  final String title;
  final IconData icon;
  final List<String> steps;
}

const firstAidVersion = 1;

const firstAidFooter = "Follow your mine's first-aid training. Call trained help.";

const List<FirstAidGuide> firstAidGuides = [
  FirstAidGuide(
    title: 'Heavy bleeding',
    icon: Icons.bloodtype,
    steps: [
      'Press firmly and directly on the wound with a clean pad or cloth.',
      'Keep pressing. If blood soaks through, add more pads on top without removing the soaked ones.',
      'Raise the injured limb above heart level if you do not suspect a fracture.',
      'Keep the person lying down and warm. Get trained help as fast as possible.',
    ],
  ),
  FirstAidGuide(
    title: 'Burns',
    icon: Icons.local_fire_department,
    steps: [
      'Cool the burn under clean running water for 20 minutes.',
      'Remove rings, watches and tight items near the burn before it swells.',
      'Cover loosely with a clean, non-fluffy dressing or cling film.',
      'Do not use creams, ice, or burst blisters.',
    ],
  ),
  FirstAidGuide(
    title: 'Smoke, gas or CO exposure',
    icon: Icons.air,
    steps: [
      'Put on your self-rescuer immediately if there is smoke or suspected carbon monoxide.',
      'Move to fresh intake air if it is safe to do so. Do not run into smoke.',
      'If the person is unconscious but breathing, place them in the recovery position.',
      'Keep them warm and still. Everyone exposed needs a medical check.',
    ],
  ),
  FirstAidGuide(
    title: 'Unconscious but breathing',
    icon: Icons.person,
    steps: [
      'Check for danger, then call for help.',
      'Open the airway: tilt the head back gently and lift the chin.',
      'Roll them onto their side into the recovery position.',
      'Stay with them and keep checking their breathing until help arrives.',
    ],
  ),
  FirstAidGuide(
    title: 'Not breathing',
    icon: Icons.monitor_heart,
    steps: [
      'Call for help and ask someone to bring the AED or first-aid kit.',
      'Start CPR: 30 chest compressions, then 2 rescue breaths.',
      'If you are untrained or unwilling to give breaths, do hands-only compressions at 100 to 120 per minute.',
      'Push hard and fast in the centre of the chest. Do not stop until help takes over.',
    ],
  ),
  FirstAidGuide(
    title: 'Suspected fracture',
    icon: Icons.personal_injury,
    steps: [
      'Keep the injured part still. Do not try to straighten it.',
      'Support it in the position found with padding or a folded cloth.',
      'Cover any open wound with a clean dressing without pressing on the bone.',
      'Treat for shock: lie them down and keep them warm. Get trained help.',
    ],
  ),
  FirstAidGuide(
    title: 'Crush injury',
    icon: Icons.warning_amber,
    steps: [
      'Only free the person if it is safe and the weight is easy to lift. Do not risk a second fall.',
      'Control any bleeding with firm pressure around the wound.',
      'Do not move them unless there is immediate danger.',
      'Keep them calm and warm and tell rescuers how long they were trapped.',
    ],
  ),
];
