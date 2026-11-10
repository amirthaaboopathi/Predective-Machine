import '../models/health_question.dart';
import '../models/health_option.dart';

/// Centralized repository containing appliance-specific diagnostic questions.
/// Expandable for any new appliance type without modifying the Health Check UI engine.
final Map<String, List<HealthQuestion>> applianceHealthQuestions = {
  'Refrigerator': [
    const HealthQuestion(
      id: 'ref_q1',
      applianceType: 'Refrigerator',
      question: 'Is the refrigerator cooling normally?',
      options: [
        HealthOption(
          id: 'ref_q1_opt1',
          label: 'Yes',
          riskScore: 0,
        ),
        HealthOption(
          id: 'ref_q1_opt2',
          label: 'Sometimes',
          riskScore: 10,
          issueDescription: 'Cooling performance is inconsistent.',
          recommendation: 'Inspect door seal gaskets and verify thermostat settings.',
        ),
        HealthOption(
          id: 'ref_q1_opt3',
          label: 'No',
          riskScore: 25,
          issueDescription: 'Severe cooling failure detected.',
          recommendation: 'Check compressor operation and clean condenser coils.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'ref_q2',
      applianceType: 'Refrigerator',
      question: 'Is there unusual noise?',
      options: [
        HealthOption(
          id: 'ref_q2_opt1',
          label: 'No',
          riskScore: 0,
        ),
        HealthOption(
          id: 'ref_q2_opt2',
          label: 'Mild',
          riskScore: 10,
          issueDescription: 'Mild mechanical or fan humming detected.',
          recommendation: 'Ensure unit is level and not touching adjacent walls.',
        ),
        HealthOption(
          id: 'ref_q2_opt3',
          label: 'Severe',
          riskScore: 20,
          issueDescription: 'Unusual compressor or fan motor noise detected.',
          recommendation: 'Inspect evaporator fan and rear compressor mounts.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'ref_q3',
      applianceType: 'Refrigerator',
      question: 'Is there excessive ice formation?',
      options: [
        HealthOption(
          id: 'ref_q3_opt1',
          label: 'No',
          riskScore: 0,
        ),
        HealthOption(
          id: 'ref_q3_opt2',
          label: 'Yes',
          riskScore: 15,
          issueDescription: 'Excessive frost buildup observed.',
          recommendation: 'Check automatic defrost timer and door sealing.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'ref_q4',
      applianceType: 'Refrigerator',
      question: 'Is power consumption unusually high?',
      options: [
        HealthOption(
          id: 'ref_q4_opt1',
          label: 'No',
          riskScore: 0,
        ),
        HealthOption(
          id: 'ref_q4_opt2',
          label: 'Yes',
          riskScore: 15,
          issueDescription: 'Elevated power consumption detected.',
          recommendation: 'Clean rear coils and lower ambient room temperature.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'ref_q5',
      applianceType: 'Refrigerator',
      question: 'Any water leakage?',
      options: [
        HealthOption(
          id: 'ref_q5_opt1',
          label: 'No',
          riskScore: 0,
        ),
        HealthOption(
          id: 'ref_q5_opt2',
          label: 'Yes',
          riskScore: 20,
          issueDescription: 'Water leakage detected under or inside unit.',
          recommendation: 'Inspect the drain system, door seal, and water collection area.',
        ),
      ],
    ),
  ],

  'Washing Machine': [
    const HealthQuestion(
      id: 'wm_q1',
      applianceType: 'Washing Machine',
      question: 'Is the machine completing the wash cycle normally?',
      options: [
        HealthOption(id: 'wm_q1_o1', label: 'Yes', riskScore: 0),
        HealthOption(
          id: 'wm_q1_o2',
          label: 'Intermittently',
          riskScore: 10,
          issueDescription: 'Wash cycles pause unexpectedly.',
          recommendation: 'Inspect control panel board and door lock assembly.',
        ),
        HealthOption(
          id: 'wm_q1_o3',
          label: 'No',
          riskScore: 25,
          issueDescription: 'Cycle fails to complete.',
          recommendation: 'Check motor drive belt and primary controller PCB.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'wm_q2',
      applianceType: 'Washing Machine',
      question: 'Is there unusual vibration?',
      options: [
        HealthOption(id: 'wm_q2_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'wm_q2_o2',
          label: 'Mild',
          riskScore: 10,
          issueDescription: 'Mild vibration during spin cycle.',
          recommendation: 'Check machine level and equalize wash loads.',
        ),
        HealthOption(
          id: 'wm_q3_o3',
          label: 'Severe',
          riskScore: 20,
          issueDescription: 'Excessive cabinet shaking during spin.',
          recommendation: 'Inspect shock absorbers and drum suspension springs.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'wm_q3',
      applianceType: 'Washing Machine',
      question: 'Is there unusual noise?',
      options: [
        HealthOption(id: 'wm_q3_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'wm_q3_o2',
          label: 'Mild',
          riskScore: 10,
          issueDescription: 'Mild grinding noise detected.',
          recommendation: 'Check coin trap and drum for foreign objects.',
        ),
        HealthOption(
          id: 'wm_q3_o3',
          label: 'Severe',
          riskScore: 15,
          issueDescription: 'Loud bearing or motor noise.',
          recommendation: 'Inspect tub bearings and drive pulley.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'wm_q4',
      applianceType: 'Washing Machine',
      question: 'Is water draining properly?',
      options: [
        HealthOption(id: 'wm_q4_o1', label: 'Yes', riskScore: 0),
        HealthOption(
          id: 'wm_q4_o2',
          label: 'Slowly',
          riskScore: 10,
          issueDescription: 'Slow water drainage.',
          recommendation: 'Clean drain pump filter and check outlet hose.',
        ),
        HealthOption(
          id: 'wm_q4_o3',
          label: 'No',
          riskScore: 20,
          issueDescription: 'Drainage blockage detected.',
          recommendation: 'Inspect drain pump impeller for clogs.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'wm_q5',
      applianceType: 'Washing Machine',
      question: 'Is there water leakage?',
      options: [
        HealthOption(id: 'wm_q5_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'wm_q5_o2',
          label: 'Yes',
          riskScore: 20,
          issueDescription: 'Water leakage around door or base.',
          recommendation: 'Inspect door boot gasket and inlet hose connections.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'wm_q6',
      applianceType: 'Washing Machine',
      question: 'Is the drum spinning normally?',
      options: [
        HealthOption(id: 'wm_q6_o1', label: 'Yes', riskScore: 0),
        HealthOption(
          id: 'wm_q6_o2',
          label: 'Wobbling',
          riskScore: 10,
          issueDescription: 'Drum wobble during rotation.',
          recommendation: 'Inspect inner tub spider arm assembly.',
        ),
        HealthOption(
          id: 'wm_q6_o3',
          label: 'No',
          riskScore: 20,
          issueDescription: 'Drum fails to spin.',
          recommendation: 'Check motor capacitor, belt, or drive motor.',
        ),
      ],
    ),
  ],

  'Air Conditioner': [
    const HealthQuestion(
      id: 'ac_q1',
      applianceType: 'Air Conditioner',
      question: 'Is the AC cooling normally?',
      options: [
        HealthOption(id: 'ac_q1_o1', label: 'Yes', riskScore: 0),
        HealthOption(
          id: 'ac_q1_o2',
          label: 'Weakly',
          riskScore: 10,
          issueDescription: 'Weak cooling output.',
          recommendation: 'Clean air filters and inspect outdoor unit coils.',
        ),
        HealthOption(
          id: 'ac_q1_o3',
          label: 'No',
          riskScore: 25,
          issueDescription: 'No cooling produced.',
          recommendation: 'Check refrigerant levels and compressor startup.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'ac_q2',
      applianceType: 'Air Conditioner',
      question: 'Is airflow normal?',
      options: [
        HealthOption(id: 'ac_q2_o1', label: 'Yes', riskScore: 0),
        HealthOption(
          id: 'ac_q2_o2',
          label: 'Weak',
          riskScore: 10,
          issueDescription: 'Restricted airflow detected.',
          recommendation: 'Clean washable mesh filters and indoor blower wheel.',
        ),
        HealthOption(
          id: 'ac_q2_o3',
          label: 'No',
          riskScore: 20,
          issueDescription: 'Airflow obstructed or blower stalled.',
          recommendation: 'Inspect indoor fan motor and louvers.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'ac_q3',
      applianceType: 'Air Conditioner',
      question: 'Is there unusual noise?',
      options: [
        HealthOption(id: 'ac_q3_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'ac_q3_o2',
          label: 'Mild',
          riskScore: 10,
          issueDescription: 'Mild vibration or rattling.',
          recommendation: 'Tighten front panel fittings and chassis screws.',
        ),
        HealthOption(
          id: 'ac_q3_o3',
          label: 'Severe',
          riskScore: 15,
          issueDescription: 'Loud rattling or grinding from indoor/outdoor unit.',
          recommendation: 'Inspect compressor fan blade and outdoor motor bearings.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'ac_q4',
      applianceType: 'Air Conditioner',
      question: 'Is there water leakage?',
      options: [
        HealthOption(id: 'ac_q4_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'ac_q4_o2',
          label: 'Yes',
          riskScore: 20,
          issueDescription: 'Water dripping from indoor unit.',
          recommendation: 'Flush drain pipe line and clean condensate tray.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'ac_q5',
      applianceType: 'Air Conditioner',
      question: 'Is power consumption unusually high?',
      options: [
        HealthOption(id: 'ac_q5_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'ac_q5_o2',
          label: 'Yes',
          riskScore: 15,
          issueDescription: 'High power consumption.',
          recommendation: 'Service outdoor heat exchanger and set optimal thermostat.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'ac_q6',
      applianceType: 'Air Conditioner',
      question: 'Is there unusual smell?',
      options: [
        HealthOption(id: 'ac_q6_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'ac_q6_o2',
          label: 'Yes',
          riskScore: 15,
          issueDescription: 'Musty smell from air vents.',
          recommendation: 'Perform antibacterial anti-mold foam coil treatment.',
        ),
      ],
    ),
  ],

  'Microwave': [
    const HealthQuestion(
      id: 'mw_q1',
      applianceType: 'Microwave',
      question: 'Is the microwave heating normally?',
      options: [
        HealthOption(id: 'mw_q1_o1', label: 'Yes', riskScore: 0),
        HealthOption(
          id: 'mw_q1_o2',
          label: 'Weakly',
          riskScore: 10,
          issueDescription: 'Heating takes longer than usual.',
          recommendation: 'Inspect magnetron power output.',
        ),
        HealthOption(
          id: 'mw_q1_o3',
          label: 'No',
          riskScore: 25,
          issueDescription: 'No heat generated.',
          recommendation: 'Inspect high-voltage diode and magnetron tube.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'mw_q2',
      applianceType: 'Microwave',
      question: 'Is there unusual noise?',
      options: [
        HealthOption(id: 'mw_q2_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'mw_q2_o2',
          label: 'Mild',
          riskScore: 10,
          issueDescription: 'Mild humming during operation.',
          recommendation: 'Ensure turntable roller ring is clean.',
        ),
        HealthOption(
          id: 'mw_q2_o3',
          label: 'Severe',
          riskScore: 20,
          issueDescription: 'Loud buzzing or grinding sound.',
          recommendation: 'Check high-voltage transformer and cooling fan motor.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'mw_q3',
      applianceType: 'Microwave',
      question: 'Are there sparks during operation?',
      options: [
        HealthOption(id: 'mw_q3_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'mw_q3_o2',
          label: 'Yes',
          riskScore: 30,
          issueDescription: 'Arcing/sparking inside cavity.',
          recommendation: 'Replace wave guide cover and clean internal walls.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'mw_q4',
      applianceType: 'Microwave',
      question: 'Is the turntable rotating normally?',
      options: [
        HealthOption(id: 'mw_q4_o1', label: 'Yes', riskScore: 0),
        HealthOption(
          id: 'mw_q4_o2',
          label: 'No',
          riskScore: 15,
          issueDescription: 'Turntable fails to rotate.',
          recommendation: 'Inspect tray coupler and turntable drive motor.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'mw_q5',
      applianceType: 'Microwave',
      question: 'Is there unusual smell?',
      options: [
        HealthOption(id: 'mw_q5_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'mw_q5_o2',
          label: 'Yes',
          riskScore: 15,
          issueDescription: 'Burnt odor emitted during use.',
          recommendation: 'Unplug unit and inspect internal wiring.',
        ),
      ],
    ),
  ],

  'Fan': [
    const HealthQuestion(
      id: 'fan_q1',
      applianceType: 'Fan',
      question: 'Is the fan rotating normally?',
      options: [
        HealthOption(id: 'fan_q1_o1', label: 'Yes', riskScore: 0),
        HealthOption(
          id: 'fan_q1_o2',
          label: 'Slow',
          riskScore: 10,
          issueDescription: 'Slower blade rotation.',
          recommendation: 'Inspect motor capacitor and shaft lubrication.',
        ),
        HealthOption(
          id: 'fan_q1_o3',
          label: 'No',
          riskScore: 25,
          issueDescription: 'Blades stuck or failing to spin.',
          recommendation: 'Check motor winding continuity and bearings.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'fan_q2',
      applianceType: 'Fan',
      question: 'Is there unusual vibration?',
      options: [
        HealthOption(id: 'fan_q2_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'fan_q2_o2',
          label: 'Mild',
          riskScore: 10,
          issueDescription: 'Mild wobble during operation.',
          recommendation: 'Tighten blade screws and balance blades.',
        ),
        HealthOption(
          id: 'fan_q2_o3',
          label: 'Severe',
          riskScore: 20,
          issueDescription: 'Severe wobbling and unbalance.',
          recommendation: 'Check motor shaft alignment and downrod mounts.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'fan_q3',
      applianceType: 'Fan',
      question: 'Is there unusual noise?',
      options: [
        HealthOption(id: 'fan_q3_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'fan_q3_o2',
          label: 'Mild',
          riskScore: 10,
          issueDescription: 'Mild humming noise.',
          recommendation: 'Apply machine oil to rotor bearings.',
        ),
        HealthOption(
          id: 'fan_q3_o3',
          label: 'Severe',
          riskScore: 15,
          issueDescription: 'Squeaking or grinding sound.',
          recommendation: 'Replace worn ball bearings.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'fan_q4',
      applianceType: 'Fan',
      question: 'Is the speed consistent?',
      options: [
        HealthOption(id: 'fan_q4_o1', label: 'Yes', riskScore: 0),
        HealthOption(
          id: 'fan_q4_o2',
          label: 'Fluctuating',
          riskScore: 15,
          issueDescription: 'Speed surges or drops.',
          recommendation: 'Check wall regulator or remote controller circuit.',
        ),
        HealthOption(
          id: 'fan_q4_o3',
          label: 'No',
          riskScore: 20,
          issueDescription: 'Speed control unresponsive.',
          recommendation: 'Inspect step capacitor switch.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'fan_q5',
      applianceType: 'Fan',
      question: 'Is the motor becoming unusually hot?',
      options: [
        HealthOption(id: 'fan_q5_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'fan_q5_o2',
          label: 'Warm',
          riskScore: 10,
          issueDescription: 'Motor housing runs warm.',
          recommendation: 'Ensure adequate room ventilation.',
        ),
        HealthOption(
          id: 'fan_q5_o3',
          label: 'Hot',
          riskScore: 25,
          issueDescription: 'Motor housing overheating.',
          recommendation: 'Turn off immediately to prevent coil burnout.',
        ),
      ],
    ),
  ],

  'Television': [
    const HealthQuestion(
      id: 'tv_q1',
      applianceType: 'Television',
      question: 'Is the display working normally?',
      options: [
        HealthOption(id: 'tv_q1_o1', label: 'Yes', riskScore: 0),
        HealthOption(
          id: 'tv_q1_o2',
          label: 'Lines/Dim',
          riskScore: 15,
          issueDescription: 'Lines or uneven dimness on screen.',
          recommendation: 'Inspect T-Con board and LED backlight strips.',
        ),
        HealthOption(
          id: 'tv_q1_o3',
          label: 'No',
          riskScore: 30,
          issueDescription: 'No picture output.',
          recommendation: 'Check display panel and power supply board.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'tv_q2',
      applianceType: 'Television',
      question: 'Is there flickering?',
      options: [
        HealthOption(id: 'tv_q2_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'tv_q2_o2',
          label: 'Occasional',
          riskScore: 10,
          issueDescription: 'Occasional screen flickering.',
          recommendation: 'Check HDMI cables and ambient light sensor settings.',
        ),
        HealthOption(
          id: 'tv_q2_o3',
          label: 'Constant',
          riskScore: 20,
          issueDescription: 'Constant display flickering.',
          recommendation: 'Inspect power supply capacitors and LED driver board.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'tv_q3',
      applianceType: 'Television',
      question: 'Is the sound working normally?',
      options: [
        HealthOption(id: 'tv_q3_o1', label: 'Yes', riskScore: 0),
        HealthOption(
          id: 'tv_q3_o2',
          label: 'Distorted',
          riskScore: 15,
          issueDescription: 'Distorted or crackling audio.',
          recommendation: 'Check speaker cones and audio output settings.',
        ),
        HealthOption(
          id: 'tv_q3_o3',
          label: 'No',
          riskScore: 20,
          issueDescription: 'No audio output.',
          recommendation: 'Inspect main board audio IC and internal speakers.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'tv_q4',
      applianceType: 'Television',
      question: 'Is the TV unexpectedly restarting?',
      options: [
        HealthOption(id: 'tv_q4_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'tv_q4_o2',
          label: 'Sometimes',
          riskScore: 15,
          issueDescription: 'Occasional auto-rebooting.',
          recommendation: 'Perform factory reset and update firmware.',
        ),
        HealthOption(
          id: 'tv_q4_o3',
          label: 'Frequently',
          riskScore: 25,
          issueDescription: 'Frequent reboot loop.',
          recommendation: 'Inspect power board and main processor heatsink.',
        ),
      ],
    ),
    const HealthQuestion(
      id: 'tv_q5',
      applianceType: 'Television',
      question: 'Is there unusual heating?',
      options: [
        HealthOption(id: 'tv_q5_o1', label: 'No', riskScore: 0),
        HealthOption(
          id: 'tv_q5_o2',
          label: 'Yes',
          riskScore: 20,
          issueDescription: 'Excessive heat near rear vents.',
          recommendation: 'Clear wall clearance and ensure unobstructed ventilation.',
        ),
      ],
    ),
  ],
};
