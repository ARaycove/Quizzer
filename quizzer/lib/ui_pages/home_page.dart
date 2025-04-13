import 'package:flutter/material.dart';

// Global variables to track current question and flip state
String currentQuestionId = "";
bool hasBeenFlipped = false;
DateTime questionDisplayTime = DateTime.now();
double elapsedTime = 0.0;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  bool _isShowingAnswer = false;
  bool _buttonsEnabled = false;
  bool _showFlagDialog = false;
  bool _showOtherOptions = false;
  final TextEditingController _flagController = TextEditingController();

  // Sample question and answer text for demonstration
  String questionText = "What is the Ebbinghaus forgetting curve and who discovered it?";
  String answerText = "The Ebbinghaus forgetting curve is a mathematical model that describes the rate at which information is forgotten over time when there is no attempt to retain it. It was discovered by Hermann Ebbinghaus in the 1880s and later confirmed in 2015 by Murre and Dros.";

  // Instead of late initialization, we'll use direct initialization with null safety
  // TODO Create an animation where the "card" flips over instead of toggling from dark to bright
  AnimationController? _animationController;
  // Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    // Initialize with a question
    currentQuestionId = "q123";
    hasBeenFlipped = false;
    questionDisplayTime = DateTime.now();
    
    // Initialize the animation controller immediately
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // _animation = Tween<double>(begin: 0, end: 1).animate(_animationController!);
  }

  @override
  void dispose() {
    _flagController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  // Function to flip the card and show answer or question
  void _flipCard() {
    setState(() {
      _isShowingAnswer = !_isShowingAnswer;
      
      // Once buttons are enabled, they stay enabled even if the card is flipped back
      if (!_buttonsEnabled) {
        _buttonsEnabled = true;
        hasBeenFlipped = true;
        
        // Calculate elapsed time (only on first flip to answer)
        final now = DateTime.now();
        elapsedTime = now.difference(questionDisplayTime).inMilliseconds / 1000;
      }
    });
  }

  // Function to handle user response
  void _handleResponse(String status) {
    // This would call answerQuestionAnswerPair() in a real implementation
    // FIXME Add in function call here to implement the actual response
    print('Response: $status, Time: $elapsedTime seconds');
    
    // Reset the UI for next question
    setState(() {
      _isShowingAnswer = false;
      _buttonsEnabled = false;
      _showOtherOptions = false;
      hasBeenFlipped = false;
      questionDisplayTime = DateTime.now();
      _animationController?.reset();
    });
  }

  // Function to handle flag submission
  void _submitFlag() {
    // This would call flagQuestionAnswerPair() in a real implementation
    // TODO Write the database functions for the Flag submission table
    // TODO integrate this function to submit the data to the backend
    print('Flag submitted: ${_flagController.text}');
    setState(() {
      _showFlagDialog = false;
      _flagController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            // This would navigate to the menu page
            // FIXME Implement redirect function to Menu Page
            // TODO need to actually write up the Menu Page
            print('Menu button pressed');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag, color: Colors.white),
            onPressed: () {
              setState(() {
                _showFlagDialog = true;
              });
            },
          ),
        ],
      ),
      body: GestureDetector(
        // Add click-off functionality to dismiss Other options submenu
        onTap: () {
          if (_showOtherOptions) {
            setState(() {
              _showOtherOptions = false;
            });
          }
        },
        child: Stack(
          children: [
            // Background logo (grayscale and blended)
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.grey,
                    BlendMode.saturation,
                  ),
                  child: Image.asset(
                    "images/quizzer_assets/quizzer_logo.png",
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            
            // Main content
            Column(
              children: [
                // Question/Answer card area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GestureDetector(
                      onTap: _flipCard,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _isShowingAnswer 
                              ? const Color.fromARGB(255, 145, 236, 247).withOpacity(0.1)
                              : Colors.black38,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color.fromARGB(255, 145, 236, 247),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              _isShowingAnswer ? answerText : questionText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Response buttons - show when buttons are enabled, regardless of card state
                if (_showOtherOptions)
                  _buildOtherOptions()
                else if (_buttonsEnabled) // Changed condition to use _buttonsEnabled
                  _buildResponseButtons()
                else
                  const SizedBox(height: 60), // Empty space when buttons not shown
              ],
            ),
            
            // Flag dialog
            if (_showFlagDialog)
              _buildFlagDialog(),
          ],
        ),
      ),
    );
  }

  // Helper to build the main response buttons row
  Widget _buildResponseButtons() {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          _buildResponseButton(
            "Yes(sure)",
            const Color.fromARGB(255, 71, 214, 93),
            "yes_sure",
          ),
          _buildResponseButton(
            "Yes(unsure)",
            const Color.fromARGB(255, 118, 214, 133),
            "yes_unsure",
          ),
          _buildResponseButton(
            "Other",
            Colors.grey,
            "other",
            isOtherButton: true,
          ),
          _buildResponseButton(
            "No(unsure)",
            const Color.fromARGB(255, 214, 118, 118),
            "no_unsure",
          ),
          _buildResponseButton(
            "No(sure)",
            const Color.fromARGB(255, 214, 71, 71),
            "no_sure",
          ),
        ],
      ),
    );
  }
  
  // Helper to build individual response button
  Widget _buildResponseButton(String label, Color color, String status, {bool isOtherButton = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: ElevatedButton(
          onPressed: () {
            if (isOtherButton) {
              setState(() {
                _showOtherOptions = true;
              });
            } else {
              _handleResponse(status);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // Helper to build the "Other" options
  Widget _buildOtherOptions() {
    // Following the mockup image design - three vertically stacked green buttons
    return Container(
      height: 180, 
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Column(
        children: [
          // "Did not read..." button
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 5.0),
              child: ElevatedButton(
                onPressed: () => _handleResponse("did_not_read"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 71, 214, 93),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text(
                  "Did Not Read the Question... Whoops",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          
          // "Too advanced" button
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 5.0),
              child: ElevatedButton(
                onPressed: () => _handleResponse("too_advanced"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 71, 214, 93),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text(
                  "This is TOO ADVANCED for me",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          
          // "Not interested" button
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 5.0),
              child: ElevatedButton(
                onPressed: () => _handleResponse("not_interested"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 71, 214, 93),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text(
                  "Just not interested in learning this",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          
          // Back button
          SizedBox(
            height: 30,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _showOtherOptions = false;
                });
              },
              child: const Text(
                "Back to Response Options",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build the flag dialog
  Widget _buildFlagDialog() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1929),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color.fromARGB(255, 145, 236, 247),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Flag Question",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _flagController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Please explain the issue with this question...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showFlagDialog = false;
                      _flagController.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: _submitFlag,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 71, 214, 93),
                  ),
                  child: const Text("Submit Flag"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}