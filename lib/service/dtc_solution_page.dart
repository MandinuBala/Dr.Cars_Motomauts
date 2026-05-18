// lib/service/dtc_solution_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dr_cars_fyp/theme/app_theme.dart';

class DTCSolutionPage extends StatelessWidget {
  final String code;

  DTCSolutionPage({Key? key, required this.code}) : super(key: key);

  // ─────────────────────────────────────────────────────────────
  // DTC DATABASE
  // Add more codes here anytime
  // ─────────────────────────────────────────────────────────────

  final Map<String, Map<String, dynamic>> dtcSolutions = {
    'P0343': {
      'meaning': 'Camshaft Position Sensor "A" Circuit High Input',

      'causes': [
        'Faulty camshaft position sensor',
        'Loose sensor connector',
        'Damaged wiring',
        'Corroded connector terminals',
        'ECU issue',
      ],

      'symptoms': [
        'Check engine light ON',
        'Hard starting',
        'Engine hesitation',
        'Poor acceleration',
        'Rough idle',
      ],

      'userFixable': true,

      'userSteps': [
        'Turn OFF the engine completely',
        'Open the hood safely',
        'Locate the camshaft position sensor',
        'Check whether the connector is loose',
        'Inspect wires for cuts or burns',
        'Reconnect the sensor firmly',
        'Restart the vehicle',
        'Clear the error code and test again',
      ],

      'mechanicRequired': true,

      'mechanicMessage':
          'Sensor voltage and ECU diagnostics require professional equipment.',
    },

    'P0101': {
      'meaning': 'Mass Air Flow Circuit Range/Performance',

      'causes': [
        'Dirty MAF sensor',
        'Air filter blockage',
        'Vacuum leak',
        'Damaged intake hose',
        'Faulty MAF sensor',
      ],

      'symptoms': [
        'Poor fuel economy',
        'Engine hesitation',
        'Weak acceleration',
        'Rough idle',
        'Check engine light',
      ],

      'userFixable': true,

      'userSteps': [
        'Turn OFF the engine',
        'Inspect the air filter',
        'Check intake pipe for leaks',
        'Clean the MAF sensor carefully',
        'Reconnect loose connectors',
        'Restart vehicle and test again',
      ],

      'mechanicRequired': false,

      'mechanicMessage':
          'If the issue continues after cleaning, sensor replacement may be needed.',
    },
  };

  @override
  Widget build(BuildContext context) {
    final data = dtcSolutions[code];

    // Fallback if code not found
    if (data == null) {
      return Scaffold(
        backgroundColor: AppColors.richBlack,
        appBar: AppBar(
          backgroundColor: AppColors.obsidian,
          foregroundColor: Colors.white,
          title: Text(
            'DTC Solution',
            style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No repair guide available for $code yet.',
              style: GoogleFonts.jost(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.richBlack,

      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        foregroundColor: Colors.white,
        title: Text(
          'DTC Solution',
          style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────
            // ERROR CODE CARD
            // ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderGold),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: GoogleFonts.jost(
                      color: AppColors.error,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    data['meaning'],
                    style: GoogleFonts.jost(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // POSSIBLE CAUSES
            // ─────────────────────────────────────────
            _sectionTitle('Possible Causes'),

            ...List.generate(
              data['causes'].length,
              (index) => _bulletItem(data['causes'][index]),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // SYMPTOMS
            // ─────────────────────────────────────────
            _sectionTitle('Symptoms'),

            ...List.generate(
              data['symptoms'].length,
              (index) => _bulletItem(data['symptoms'][index]),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // USER FIXABLE
            // ─────────────────────────────────────────
            _sectionTitle('Can User Fix This?'),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),

              decoration: BoxDecoration(
                color:
                    data['userFixable']
                        ? AppColors.success.withOpacity(0.15)
                        : AppColors.error.withOpacity(0.15),

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color:
                      data['userFixable'] ? AppColors.success : AppColors.error,
                ),
              ),

              child: Text(
                data['userFixable']
                    ? 'YES - Basic inspection possible'
                    : 'NO - Professional repair required',

                style: GoogleFonts.jost(
                  color:
                      data['userFixable'] ? AppColors.success : AppColors.error,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // USER STEPS
            // ─────────────────────────────────────────
            _sectionTitle('What You Can Check'),

            ...List.generate(
              data['userSteps'].length,
              (index) => _numberItem(index + 1, data['userSteps'][index]),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────
            // MECHANIC REQUIRED
            // ─────────────────────────────────────────
            _sectionTitle('Mechanic Recommendation'),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      data['mechanicRequired']
                          ? AppColors.error
                          : AppColors.success,
                ),
              ),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    data['mechanicRequired']
                        ? Icons.build_circle
                        : Icons.check_circle,

                    color:
                        data['mechanicRequired']
                            ? AppColors.error
                            : AppColors.success,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      data['mechanicMessage'],
                      style: GoogleFonts.jost(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SECTION TITLE
  // ─────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.jost(
          color: AppColors.gold,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BULLET ITEM
  // ─────────────────────────────────────────────

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 7, color: AppColors.gold),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              style: GoogleFonts.jost(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // NUMBER ITEM
  // ─────────────────────────────────────────────

  Widget _numberItem(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,

            alignment: Alignment.center,

            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(20),
            ),

            child: Text(
              number.toString(),
              style: GoogleFonts.jost(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              text,
              style: GoogleFonts.jost(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
