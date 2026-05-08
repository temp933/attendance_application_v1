import 'package:flutter/material.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? size.width * 0.15 : 16,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            Text(
              "My Tasks",
              style: TextStyle(
                fontSize: isDesktop ? 28 : 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Assigned tasks for this week",
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 24),

            /// TASK LIST
            taskCard(
              title: "Attendance Module UI",
              description:
                  "Design and implement attendance check-in & calendar UI",
              period: "Week 1 (01 Dec - 07 Dec)",
              status: TaskStatus.inProgress,
            ),

            taskCard(
              title: "Leave Module",
              description: "Create leave apply form and leave history screen",
              period: "Week 1 (01 Jan - 07 Jan)",
              status: TaskStatus.pending,
            ),

            taskCard(
              title: "Bug Fixes",
              description: "Fix UI overflow and calendar date selection issues",
              period: "Week 2 (08 Dec - 14 Dec)",
              status: TaskStatus.completed,
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= TASK CARD =================
Widget taskCard({
  required String title,
  required String description,
  required String period,
  required TaskStatus status,
}) {
  final Color statusColor = getStatusColor(status);
  final String statusText = getStatusText(status);

  return Card(
    elevation: 3,
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TITLE + STATUS
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          /// DESCRIPTION
          Text(description, style: const TextStyle(color: Colors.black87)),

          const SizedBox(height: 14),

          /// PERIOD
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(period, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    ),
  );
}

/// ================= STATUS ENUM =================
enum TaskStatus { pending, inProgress, completed }

String getStatusText(TaskStatus status) {
  switch (status) {
    case TaskStatus.pending:
      return "Pending";
    case TaskStatus.inProgress:
      return "In Progress";
    case TaskStatus.completed:
      return "Completed";
  }
}

Color getStatusColor(TaskStatus status) {
  switch (status) {
    case TaskStatus.pending:
      return Colors.orange;
    case TaskStatus.inProgress:
      return Colors.blue;
    case TaskStatus.completed:
      return Colors.green;
  }
}
