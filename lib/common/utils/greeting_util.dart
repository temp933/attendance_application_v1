String getGreeting() {
  final hour = DateTime.now().hour;

  if (hour >= 5 && hour < 12) {
    return "Good Morning 👋";
  } else if (hour >= 12 && hour < 17) {
    return "Good Afternoon 👋";
  } else {
    return "Good Evening 👋";
  }
}
