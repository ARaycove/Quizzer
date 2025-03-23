import logging
import os
import sys
import functools
import inspect
from datetime   import datetime
from pathlib    import Path

logs_dir = Path("quizzer_logs")
logs_dir.mkdir(exist_ok=True)

log_filename = logs_dir / f"quizzer.log" # Fucking GIPPITY would rather you timestamp it so we produce a million fucking log files, fucking idiot

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_filename, mode="w"),
        # logging.StreamHandler(sys.stdout)
    ]
)

# Cache loggers by module name
_loggers = {}

def get_logger(module_name=None):
    '''
    Get a logger for the specified module.
    If module_name is None, uses the caller's module name.
    '''
    if module_name is None:
        frame = inspect.currentframe().f_back
        module_name = frame.f_globals['__name__']
    if module_name in _loggers:
        return _loggers[module_name]
    logger = logging.getLogger(f"quizzer.{module_name}")
    _loggers[module_name] = logger
    return logger

def log_function(level='DEBUG'):
    '''
    Decorator to log function calls with a small header
    Takes the logger level as an argument, default to 'INFO'
    Usage:
    @log_function() 
    def some_function(args):
        ...
    @log_function('DEBUG')
    def some_function(args):
        ...
    etc.
    '''
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            # Get the module name from the function
            module_name = func.__module__.split('.')[-1]
            logger = get_logger(module_name)
            # Log function entry
            log_method = getattr(logger, level.lower())
            arg_str = ', '.join([repr(a) for a in args] + [f"{k}={repr(v)}" for k, v in kwargs.items()])
            log_method(f"--- FUNCTION CALL: {func.__name__}({arg_str}) ---")
            # Call the function
            try:
                result = func(*args, **kwargs)
                log_method(f"--- END FUNCTION: {func.__name__} ---")
                return result
            except Exception as e:
                logger.error(f"!!! ERROR IN {func.__name__}: {type(e).__name__}: {str(e)}")
                raise
        return wrapper
    return decorator

def log_main_header(header_text: str, module_name=None):
    '''
    Logs the provided text as a Large Header
    '''
    logger = get_logger(module_name)
    header = f"\n{'=' * 80}\n{header_text.center(80)}\n{'=' * 80}"
    logger.info(header)

def log_section_header(section_header, module_name=None):
    """
    Logs a section header (smaller than log_header).
    
    Usage:
        log_section("Processing User Data")
    """
    logger = get_logger(module_name)
    section = f"\n{'-' * 50}\n{section_header}\n{'-' * 50}"
    logger.info(section)

def log_value(name_of_variable: str, value_of_variable, module_name = None):
    '''
    Logs the provided variable
    '''
    logger = get_logger(module_name)
    logger.info(f"Type({type(value_of_variable)}) {name_of_variable:25}: {value_of_variable}")

def log_general_message(message_text: str, module_name = None):
    '''
    Writes a basic log message (generic)
    '''
    logger = get_logger(module_name)
    logger.info(str(message_text))

def log_success_message(text, module_name=None):
    """
    Logs a success message with visual indicators.\n
    Output: f"✓ SUCCESS: {text}"
    """
    logger = get_logger(module_name)
    logger.info(f"✓ SUCCESS: {text}")

def log_warning(text, module_name=None):
    """
    Logs a warning message with visual indicators.\n
    Output: f"⚠ WARNING: {text}"
    """
    logger = get_logger(module_name)
    logger.warning(f"⚠ WARNING: {text}")    

def log_error(text, exception=None, module_name=None):
    """
    Logs an error message with visual indicators.
    Optionally includes exception details.
    
    Usage:
        log_error("Failed to connect to database")
        log_error("Failed to process file", exception=e)
    """
    logger = get_logger(module_name)
    error_msg = f"✗ ERROR: {text}"
    if exception:
        error_msg += f" - {type(exception).__name__}: {str(exception)}"
    logger.error(error_msg, exc_info=bool(exception))

def set_log_level(level, module_name=None):
    """
    Set the log level for a specific module or the root logger.
    
    Usage:
        set_log_level(logging.DEBUG)  # Set root logger to DEBUG
        set_log_level(logging.INFO, "quizzer.user_profile")  # Set specific module
    """
    logger = get_logger(module_name)
    logger.setLevel(level)