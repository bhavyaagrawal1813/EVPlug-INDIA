import 'package:flutter/material.dart';

import 'home_content.dart';
import 'ev_ai_screen.dart';
import 'saved_screen.dart';
import 'add_station.dart';
import 'profile_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // ================= SELECTED TAB =================

  int selectedIndex = 0;

  // ================= SCREENS =================
  // ONLY UI NAVIGATION
  // NO BUSINESS LOGIC HERE

 final List<Widget> screens = [
  const HomeContentScreen(),
  const EvAiScreen(),
  const AddStationScreen(),
  const SavedScreen(),
  const ProfileScreen(),
];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),

      // ================= BODY =================

      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),

      // ================= FLOATING BUTTON =================

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00FFAA),

        elevation: 4,

          onPressed: () {
            setState(() {
              selectedIndex = 2;
            });
          },

        child: const Icon(
          Icons.add,
          color: Colors.black,
          size: 30,
        ),
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation
              .centerDocked,

      // ================= BOTTOM NAVIGATION =================

      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF0B1220),

        shape:
            const CircularNotchedRectangle(),

        notchMargin: 8,

        child: SizedBox(
          height: 70,

          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,

            children: [

              // HOME

              buildNavItem(
                icon: Icons.home,
                label: "Home",
                index: 0,
              ),

              // MAPS
            buildNavItem(
              icon: Icons.auto_awesome,
              label: "EV AI",
              index: 1,
            ),

              const SizedBox(width: 40),

              // SAVED

              buildNavItem(
                icon: Icons.bookmark,
                label: "Saved",
                index: 3,
              ),

              // PROFILE

              buildNavItem(
                icon: Icons.person,
                label: "Profile",
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= NAV ITEM WIDGET =================

  Widget buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {

    final bool isSelected =
        selectedIndex == index;

    return InkWell(
      borderRadius:
          BorderRadius.circular(12),

      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },

      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [

            Icon(
              icon,

              color: isSelected
                  ? const Color(0xFF00FFAA)
                  : Colors.white38,
            ),

            const SizedBox(height: 4),

            Text(
              label,

              style: TextStyle(
                fontSize: 12,

                color: isSelected
                    ? const Color(0xFF00FFAA)
                    : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
