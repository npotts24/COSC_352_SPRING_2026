

set -uo pipefail

# Configuration
PROJECTS=(project01 project02)
STUDENT_DIR="../.."
TEST_DIR="./tests"
LOG_FILE="grading_$(date +%Y%m%d_%H%M%S).log"

# Counters
pass=0
fail=0
total=0

# Track images for cleanup
declare -a IMAGES_BUILT=()

# Helper function
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

# Preflight checks
if ! command -v docker >/dev/null 2>&1; then
    log "ERROR: Docker not found"
    exit 2
fi

if ! docker info >/dev/null 2>&1; then
    log "ERROR: Cannot connect to Docker daemon"
    exit 2
fi



# Iterate through each project
for proj in "${PROJECTS[@]}"; do
    testsdir="$TEST_DIR/$proj"
    
    # Skip if no tests for this project
    if [ ! -d "$testsdir" ]; then
        log "No tests for $proj"
        continue
    fi
    
    log ""
    log "Project: $proj"
    
    # Iterate through student directories
    for student_path in "$STUDENT_DIR"/*/"$proj"; do
        [ -d "$student_path" ] || continue
        
        student=$(basename "$(dirname "$student_path")")
        
        # Skip if no Dockerfile
        if [ ! -f "$student_path/Dockerfile" ]; then
            log "  $student: no Dockerfile"
            continue
        fi
        
        log ""
        log "  Grading: $student"
        
        # Build image
        img="${student}_${proj}"
        log "    Building..."
        
        if ! docker build -t "$img" "$student_path" >> "$LOG_FILE" 2>&1; then
            log "    BUILD FAIL"
            ((fail++))
            continue
        fi
        
        IMAGES_BUILT+=("$img")
        
        # Run each test
        for input_file in "$testsdir"/*.in; do
            [ -e "$input_file" ] || break
            
            name=$(basename "$input_file" .in)
            expected_file="$testsdir/${name}.expected"
            out=$(mktemp /tmp/grader_out.XXXXXX)
            
            log "    Test: $name"
            
            ((total++))
            
            # Run container with test input
            if ! bash -c "cat '$input_file' | docker run --rm -i '$img'" > "$out" 2>>"$LOG_FILE"; then
                log "      FAIL - runtime error"
                ((fail++))
                rm -f "$out"
                continue
            fi
            
            # Compare output
            if [ -f "$expected_file" ]; then
                if diff -q "$expected_file" "$out" >/dev/null 2>&1; then
                    log "      PASS"
                    ((pass++))
                else
                    log "      FAIL"
                    diff -u "$expected_file" "$out" | sed 's/^/        /' >> "$LOG_FILE"
                    ((fail++))
                fi
            else
                log "      FAIL - missing expected file"
                ((fail++))
            fi
            
            rm -f "$out"
        done
        
        # Cleanup image
        docker rmi -f "$img" >/dev/null 2>&1 || true
    done
done



if [ "$total" -gt 0 ]; then
    score=$((pass * 100 / total))
    log "Score: $score%"
fi

log "Grading complete. Log saved to $LOG_FILE"

exit 0