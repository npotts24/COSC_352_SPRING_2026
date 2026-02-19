#!/bin/bash

################################################################################
# Grading Utilities Script
#
# Provides helper commands for managing grading results and cleanup
# Usage: ./grade-utils.sh [command] [options]
################################################################################

WORKSPACE_ROOT="/workspaces/COSC_352_SPRING_2026"
GRADING_DIR="${WORKSPACE_ROOT}/obaloluwa_wojuade/project03"
LOG_DIR="${WORKSPACE_ROOT}/grading_logs"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Show help
################################################################################
show_help() {
    cat << 'EOF'
Grading Utilities
Usage: ./grade-utils.sh [command] [options]

COMMANDS:

  logs              View grading logs
    view [log]       View a specific log file (lists if not specified)
    latest           Show the most recent grading log
    follow           Follow latest log in real-time
    grep PATTERN     Search logs for a pattern

  results           Analyze grading results
    summary          Show summary of latest grading
    pass-list        List all students who passed
    fail-list        List all students who failed
    scores           Show all student scores
    project [NUM]    Show results for specific project

  cleanup           Clean up containers and images
    docker           Remove grading Docker images and containers
    logs [NUM]       Keep only last N logs (default 5)
    temp             Remove temporary files
    all              Clean everything (images, containers, temp, old logs)

  test              Test the grading system
    system           Run system validation tests
    single STUDENT   Grade one student and show output

  export            Export results
    csv              Export grading results as CSV
    json             Export as JSON

  stats             Calculate statistics
    class            Show class statistics
    project [NUM]    Show stats for project

EXAMPLES:

  # View latest grading results
  ./grade-utils.sh logs latest

  # List all passing students
  ./grade-utils.sh results pass-list

  # Search logs for specific student
  ./grade-utils.sh logs grep john_doe

  # Clean up old Docker images
  ./grade-utils.sh cleanup docker

  # Test grading system before running
  ./grade-utils.sh test system

  # Get class statistics
  ./grade-utils.sh stats class

EOF
}

################################################################################
# LOGS COMMANDS
################################################################################

logs_view() {
    if [[ -n "$1" ]]; then
        if [[ -f "${LOG_DIR}/$1" ]]; then
            less "${LOG_DIR}/$1"
        else
            echo "Log file not found: $1"
            logs_list
        fi
    else
        logs_list
    fi
}

logs_list() {
    if [[ ! -d "${LOG_DIR}" ]]; then
        echo "No logs directory found"
        return 1
    fi
    
    echo "Available log files:"
    ls -lh "${LOG_DIR}"/grading_*.log 2>/dev/null | awk '{print NR": " $NF}' | sort -r
}

logs_latest() {
    local latest=$(ls -t "${LOG_DIR}"/grading_*.log 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "No log files found"
        return 1
    fi
    less "$latest"
}

logs_follow() {
    local latest=$(ls -t "${LOG_DIR}"/grading_*.log 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "No log files found"
        return 1
    fi
    tail -f "$latest"
}

logs_grep() {
    local pattern=$1
    if [[ -z "$pattern" ]]; then
        echo "Usage: logs_grep PATTERN"
        return 1
    fi
    grep --color=auto "$pattern" "${LOG_DIR}"/grading_*.log 2>/dev/null
}

################################################################################
# RESULTS COMMANDS
################################################################################

results_summary() {
    local latest=$(ls -t "${LOG_DIR}"/grading_*.log 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "No log files found"
        return 1
    fi
    
    echo "=== Latest Grading Summary ==="
    echo "Log: $(basename $latest)"
    echo ""
    
    grep "Final Score:" "$latest" | wc -l | xargs echo "Total Students:"
    grep "Status: PASS" "$latest" | wc -l | xargs echo "Passed:"
    grep "Status: FAIL" "$latest" | wc -l | xargs echo "Failed:"
    
    echo ""
    echo "Average Score: $(grep "Final Score:" "$latest" | awk -F'[/:]/'{print $3}' | sed 's|/100||g' | awk '{sum+=$1; count++} END {printf "%.1f\n", sum/count}')"
}

results_pass_list() {
    local latest=$(ls -t "${LOG_DIR}"/grading_*.log 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "No log files found"
        return 1
    fi
    
    echo "=== Students Who Passed ==="
    grep "Status: PASS" "$latest" | grep "Grading:" | awk '{print $NF}' | sort | uniq
}

results_fail_list() {
    local latest=$(ls -t "${LOG_DIR}"/grading_*.log 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "No log files found"
        return 1
    fi
    
    echo "=== Students Who Failed ==="
    grep "Status: FAIL" "$latest" | grep "Grading:" | awk '{print $NF}' | sort | uniq
}

results_scores() {
    local latest=$(ls -t "${LOG_DIR}"/grading_*.log 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "No log files found"
        return 1
    fi
    
    echo "=== Student Scores ==="
    grep -B5 "Final Score:" "$latest" | grep "Grading:\|Final Score:" | paste - - | awk '{gsub(/.*Grading: /, "", $1); gsub(/.*Final Score: /, "  Score: ", $2); print $1 $2}' | sort
}

################################################################################
# CLEANUP COMMANDS
################################################################################

cleanup_docker() {
    echo "Cleaning up Docker images and containers..."
    
    # Remove grading containers
    docker ps -a | grep "cosc352_" | awk '{print $1}' | xargs -r docker rm -f
    
    # Remove grading images
    docker images | grep "cosc352_" | awk '{print $3}' | xargs -r docker rmi -f
    
    echo "Docker cleanup complete"
}

cleanup_logs() {
    local keep=${1:-5}
    echo "Keeping last $keep log files, removing older ones..."
    
    ls -t "${LOG_DIR}"/grading_*.log 2>/dev/null | tail -n +$((keep+1)) | xargs -r rm
    
    echo "Log cleanup complete"
}

cleanup_temp() {
    echo "Removing temporary files..."
    rm -rf /tmp/grading_temp_* 2>/dev/null
    echo "Temp cleanup complete"
}

cleanup_all() {
    echo "Performing full cleanup..."
    cleanup_docker
    cleanup_temp
    cleanup_logs 3
    echo "Full cleanup complete"
}

################################################################################
# TEST COMMANDS
################################################################################

test_system() {
    if [[ -f "${GRADING_DIR}/test-system.sh" ]]; then
        "${GRADING_DIR}/test-system.sh"
    else
        echo "Test script not found"
        return 1
    fi
}

test_single() {
    local student=$1
    if [[ -z "$student" ]]; then
        echo "Usage: test_single STUDENT_NAME"
        return 1
    fi
    
    echo "Grading $student for all projects..."
    "${GRADING_DIR}/grade.sh" -s "$student"
}

################################################################################
# EXPORT COMMANDS
################################################################################

export_csv() {
    local latest=$(ls -t "${LOG_DIR}"/grading_*.log 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "No log files found"
        return 1
    fi
    
    local output="${LOG_DIR}/results_$(date +%Y%m%d_%H%M%S).csv"
    
    {
        echo "Student,Project,Score,Status"
        grep -B5 "Final Score:" "$latest" | grep "Grading:\|Final Score:" | paste - - | \
            awk '{
                gsub(/.*Grading: /, "", $1);
                gsub(/.*\/project/, "0", $1);
                gsub(/.*Final Score: /, "", $2);
                gsub(/\/100.*/, "", $2);
                status = ($2 >= 70) ? "PASS" : "FAIL";
                print $1 "," $2 "," status
            }' | sort
    } > "$output"
    
    echo "Results exported to: $output"
    cat "$output"
}

export_json() {
    local latest=$(ls -t "${LOG_DIR}"/grading_*.log 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "No log files found"
        return 1
    fi
    
    local output="${LOG_DIR}/results_$(date +%Y%m%d_%H%M%S).json"
    
    echo "{" > "$output"
    echo '  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)',"' >> "$output"
    echo '  "results": [' >> "$output"
    
    grep -B5 "Final Score:" "$latest" | grep "Grading:\|Final Score:" | paste - - | \
        awk 'NR>1 {print ","} {
            gsub(/.*Grading: /, "", $1);
            match($1, /([^/]+)\/project([0-9]+)/, m);
            student=m[1];
            project=m[2];
            gsub(/.*Final Score: /, "", $2);
            gsub(/\/100.*/, "", $2);
            status = ($2 >= 70) ? "PASS" : "FAIL";
            printf "    {\"student\": \"%s\", \"project\": \"%s\", \"score\": %s, \"status\": \"%s\"}", student, project, $2, status
        }' >> "$output"
    
    echo "" >> "$output"
    echo "  ]" >> "$output"
    echo "}" >> "$output"
    
    echo "Results exported to: $output"
}

################################################################################
# STATS COMMANDS
################################################################################

stats_class() {
    local latest=$(ls -t "${LOG_DIR}"/grading_*.log 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "No log files found"
        return 1
    fi
    
    echo "=== Class Statistics ==="
    echo ""
    
    local total=$(grep "Final Score:" "$latest" | wc -l)
    local passed=$(grep "Status: PASS" "$latest" | wc -l)
    local failed=$((total - passed))
    local pass_rate=$((passed * 100 / total))
    
    echo "Total Submissions: $total"
    echo "Passed: $passed (${pass_rate}%)"
    echo "Failed: $failed"
    echo ""
    
    local scores=$(grep "Final Score:" "$latest" | awk -F'[/:]/'{print $3}' | sed 's|/100||g')
    local avg=$(echo "$scores" | awk '{sum+=$1; count++} END {printf "%.1f", sum/count}')
    local max=$(echo "$scores" | sort -rn | head -1)
    local min=$(echo "$scores" | sort -n | head -1)
    
    echo "Score Statistics:"
    echo "  Average: $avg"
    echo "  Maximum: $max"
    echo "  Minimum: $min"
    echo ""
    
    # Grade distribution
    echo "Grade Distribution:"
    echo -n "  A (90-100): "
    echo "$scores" | awk '$1>=90' | wc -l
    echo -n "  B (80-89):  "
    echo "$scores" | awk '$1>=80 && $1<90' | wc -l
    echo -n "  C (70-79):  "
    echo "$scores" | awk '$1>=70 && $1<80' | wc -l
    echo -n "  F (<70):    "
    echo "$scores" | awk '$1<70' | wc -l
}

stats_project() {
    local project=$1
    if [[ -z "$project" ]]; then
        echo "Usage: stats_project PROJECT_NUMBER"
        return 1
    fi
    
    # This would require parsing logs by project
    # For now, show basic info
    echo "Project $project statistics would go here"
    echo "This requires enhanced log parsing per project"
}

################################################################################
# MAIN
################################################################################

# Check if command provided
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

command=$1
shift

case $command in
    logs)
        subcommand=$1
        shift
        case $subcommand in
            view)
                logs_view "$@"
                ;;
            latest)
                logs_latest
                ;;
            follow)
                logs_follow
                ;;
            grep)
                logs_grep "$@"
                ;;
            *)
                logs_list
                ;;
        esac
        ;;
    
    results)
        subcommand=$1
        shift
        case $subcommand in
            summary)
                results_summary
                ;;
            pass-list)
                results_pass_list
                ;;
            fail-list)
                results_fail_list
                ;;
            scores)
                results_scores
                ;;
            project)
                echo "Project-specific results: $@"
                ;;
            *)
                results_summary
                ;;
        esac
        ;;
    
    cleanup)
        subcommand=$1
        shift
        case $subcommand in
            docker)
                cleanup_docker
                ;;
            logs)
                cleanup_logs "$@"
                ;;
            temp)
                cleanup_temp
                ;;
            all)
                cleanup_all
                ;;
            *)
                echo "Unknown cleanup command: $subcommand"
                ;;
        esac
        ;;
    
    test)
        subcommand=$1
        shift
        case $subcommand in
            system)
                test_system
                ;;
            single)
                test_single "$@"
                ;;
            *)
                test_system
                ;;
        esac
        ;;
    
    export)
        subcommand=$1
        shift
        case $subcommand in
            csv)
                export_csv
                ;;
            json)
                export_json
                ;;
            *)
                echo "Unknown export format: $subcommand"
                ;;
        esac
        ;;
    
    stats)
        subcommand=$1
        shift
        case $subcommand in
            class)
                stats_class
                ;;
            project)
                stats_project "$@"
                ;;
            *)
                stats_class
                ;;
        esac
        ;;
    
    -h|--help|help)
        show_help
        ;;
    
    *)
        echo "Unknown command: $command"
        show_help
        exit 1
        ;;
esac
