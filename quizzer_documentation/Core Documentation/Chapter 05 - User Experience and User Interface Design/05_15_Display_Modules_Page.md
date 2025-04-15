# Display Modules Page

## Purpose
The Display Modules Page provides users with a centralized interface to manage their learning modules. It allows users to view, activate, and deactivate curated sets of question-answer pairs, enabling them to control which knowledge domains they engage with during their learning sessions.

## Rule of thumb
- All UI elements should have uniform height
- Module cards should maintain consistent dimensions
- Should follow the same color scheme as the rest of the application
- Toggle switches should be clearly visible and easily clickable
- Search and filter elements should be prominently displayed at the top

## Interface Elements

### Module List Display
- **Module Cards**: Each module is displayed as an interactive card showing:
  - Module name
  - Description
  - Primary subject
  - Total number of questions
  - Completion status (percentage of questions in circulation)
  - Activation toggle switch
  - Subject tags
  - Related concepts

### Module Details Panel
- **Expanded View**: When a module card is selected, shows:
  - Detailed description
  - Complete list of subjects covered
  - Full list of related concepts
  - Question distribution statistics
  - Creation date and creator information
  - Last modification timestamp

### Filtering and Search
- **Search Bar**: Allows searching modules by name, subject, or concept
- **Subject Filter**: Dropdown to filter modules by primary subject
- **Sort Options**: Sort modules by:
  - Alphabetical order
  - Creation date
  - Question count
  - Completion status

### Module Management
- **Activation Toggle**: Switch to enable/disable module participation in learning sessions
- **Progress Indicator**: Visual representation of module completion status
- **Quick Actions**: Buttons for common operations:
  - View module statistics
  - Export module data
  - Share module (if enabled)

## Buttons
- **Back Button**
  - Returns to the previous page
  - Located in the top-left corner
  - Uses standard back arrow icon
- **Search Button**
  - Activates the search functionality
  - Located next to the search bar
  - Uses magnifying glass icon
- **Filter Button**
  - Opens filter options
  - Located next to the search button
  - Uses filter icon
- **Sort Button**
  - Opens sort options
  - Located next to the filter button
  - Uses sort icon
- **Module Card Toggle**
  - Enables/disables module
  - Located on each module card
  - Uses standard toggle switch
- **Details Button**
  - Expands module details
  - Located on each module card
  - Uses chevron icon

## Functionality

When a user interacts with the interface:
1. **Module Activation**:
   - Toggling a module on/off updates the `activation_status_of_modules` in the User_Profile_Table
   - Active modules become eligible for question circulation
   - Inactive modules are excluded from learning sessions

2. **Progress Tracking**:
   - System calculates completion status based on questions in circulation
   - Updates `completion_status_of_modules` in User_Profile_Table
   - Displays real-time progress indicators

3. **Data Synchronization**:
   - Module metadata is loaded from the Modules_Table
   - User-specific activation status is loaded from User_Profile_Table
   - Changes are synchronized with the database in real-time

## User Experience Notes
- Maintain dark theme (Color(0xFF0A1929)) with light green accents
- Provide clear visual feedback for module activation status
- Show loading indicators during data synchronization
- Implement smooth animations for module card interactions
- Use intuitive icons and color coding for different module states
- Provide tooltips for complex features
- Ensure responsive design for all screen sizes
- Display clear error messages for failed operations
- Implement proper loading states for data fetching

## Implementation Notes
- Follow the application's dark theme with light green accents
- Use Flutter's ReorderableListView for module card organization
- Implement proper error handling for database operations
- Include logging for all user interactions
- Cache module data for offline access
- Optimize performance for large module lists
- Ensure proper state management for module activation
- Implement proper data validation and error handling
- Use proper database transaction handling
- Implement proper offline/online synchronization

## Technical Dependencies
- [[08_04_Modules_Table]]: Source of module metadata
- [[08_02_01_User_Profiles_Table]]: Stores user-specific module activation status
- [[09_14_Module_Background_Process]]: Handles module data updates
- [[07_14_addQuestionAnswerPair()]]: Used when adding new questions to modules

Manifestation of the [[06_02_Module_System]]