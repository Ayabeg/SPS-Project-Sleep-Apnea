#!/usr/bin/env python3
"""Analyze DREAMT subjects and compare respiratory events by sleep phase."""

from __future__ import annotations

import argparse
import csv
import json
import math
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


EVENT_COLUMNS = (
    "Obstructive_Apnea",
    "Central_Apnea",
    "Hypopnea",
    "Multiple_Events",
)

# ``Multiple_Events`` is present in the raw DREAMT files but is not emitted by
# the lightweight filtered examples.  The three core event columns are enough
# to run the analysis, so keep the extra column optional for compatibility.
REQUIRED_COLUMNS = {
    "TIMESTAMP",
    "Sleep_Stage",
    "Obstructive_Apnea",
    "Central_Apnea",
    "Hypopnea",
}

STAGE_TO_PHASE = {
    "R": "REM",
    "N1": "NREM",
    "N2": "NREM",
    "N3": "NREM",
}

PHASES = ("REM", "NREM")


def parse_args() -> argparse.Namespace:
    """Read command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Analyze respiratory events in one or more DREAMT subject CSVs."
    )
    input_source = parser.add_mutually_exclusive_group(required=True)
    input_source.add_argument(
        "--input",
        type=Path,
        help="Path to one subject CSV file, for example S002_whole_df.csv.",
    )
    input_source.add_argument(
        "--input-dir",
        type=Path,
        help="Directory containing files named S002_whole_df.csv, S003_whole_df.csv, etc.",
    )
    parser.add_argument(
        "--subject",
        help="Subject label for single-file mode, for example S002.",
    )
    parser.add_argument(
        "--subjects",
        nargs="+",
        default=["S002", "S003", "S004", "S005", "S006", "S007", "S008"],
        help="Subject labels for directory mode. Defaults to S002 through S008.",
    )
    parser.add_argument(
        "--file-suffix",
        default="_whole_df.csv",
        help="Filename suffix used in directory mode (default: _whole_df.csv).",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("results"),
        help="Directory where the CSV and JSON results will be written.",
    )
    return parser.parse_args()


def is_marked(value: str | None) -> bool:
    """Return True when an event column contains an event marker."""
    if value is None:
        return False
    return value.strip().lower() not in {"", "0", "0.0", "nan", "null", "none"}


def frequency_per_hour(event_count: int, seconds: float) -> float | None:
    """Calculate events per hour, or None when the phase has no duration."""
    if seconds <= 0:
        return None
    return round(event_count / (seconds / 3600), 6)


def analyze_csv(input_path: Path) -> dict[str, Any]:
    """Analyze one subject while streaming through the CSV file."""
    if not input_path.is_file():
        raise FileNotFoundError(f"Input file does not exist: {input_path}")

    row_count = 0
    sleep_stage_counts: Counter[str] = Counter()
    sleep_phase_row_counts: Counter[str] = Counter()
    event_value_counts: dict[str, Counter[str]] = defaultdict(Counter)
    event_marked_row_counts: Counter[str] = Counter()
    event_episode_counts: Counter[str] = Counter()
    event_episode_counts_by_phase: dict[str, Counter[str]] = defaultdict(Counter)
    event_active: dict[str, bool] = defaultdict(bool)

    total_event_episodes = 0
    total_event_episodes_by_phase: Counter[str] = Counter()
    outside_sleep_event_episodes = 0

    timestamp_first: float | None = None
    timestamp_last: float | None = None
    timestamp_step_counts: Counter[float] = Counter()
    previous_timestamp: float | None = None
    previous_any_event = False

    with input_path.open("r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        fieldnames = set(reader.fieldnames or [])
        missing_columns = REQUIRED_COLUMNS - fieldnames
        if missing_columns:
            missing = ", ".join(sorted(missing_columns))
            raise ValueError(f"Missing required columns: {missing}")

        for row in reader:
            row_count += 1

            try:
                timestamp = float(row["TIMESTAMP"])
            except (TypeError, ValueError) as exc:
                raise ValueError(
                    f"Invalid TIMESTAMP at CSV row {row_count + 1}: {row['TIMESTAMP']!r}"
                ) from exc
            if not math.isfinite(timestamp):
                raise ValueError(
                    f"TIMESTAMP must be finite at CSV row {row_count + 1}: {timestamp!r}"
                )
            if timestamp_first is None:
                timestamp_first = timestamp
            if previous_timestamp is not None:
                step = round(timestamp - previous_timestamp, 9)
                if step <= 0:
                    raise ValueError(
                        "TIMESTAMP values must be strictly increasing; "
                        f"invalid step {step} at CSV row {row_count + 1}."
                    )
                timestamp_step_counts[step] += 1
            previous_timestamp = timestamp
            timestamp_last = timestamp

            stage = (row["Sleep_Stage"] or "").strip() or "<missing>"
            phase = STAGE_TO_PHASE.get(stage)
            sleep_stage_counts[stage] += 1
            if phase:
                sleep_phase_row_counts[phase] += 1

            current_event_columns: list[str] = []
            for column in EVENT_COLUMNS:
                value = (row.get(column) or "").strip()
                marked = is_marked(value)
                if marked:
                    current_event_columns.append(column)
                    event_value_counts[column][value] += 1
                    event_marked_row_counts[column] += 1
                    if not event_active[column]:
                        event_episode_counts[column] += 1
                        if phase:
                            event_episode_counts_by_phase[column][phase] += 1
                event_active[column] = marked

            any_event = bool(current_event_columns)
            if any_event and not previous_any_event:
                total_event_episodes += 1
                if phase:
                    total_event_episodes_by_phase[phase] += 1
                else:
                    outside_sleep_event_episodes += 1
            previous_any_event = any_event

    if not timestamp_step_counts:
        raise ValueError("The CSV does not contain enough timestamps to measure time.")

    sample_interval = timestamp_step_counts.most_common(1)[0][0]
    irregular_steps = [
        step
        for step in timestamp_step_counts
        if not math.isclose(step, sample_interval, rel_tol=1e-6, abs_tol=1e-9)
    ]
    if irregular_steps:
        observed = sorted(timestamp_step_counts)
        raise ValueError(
            "TIMESTAMP values are not regularly sampled; "
            f"observed intervals: {observed}."
        )
    phase_seconds = {
        phase: round(sleep_phase_row_counts[phase] * sample_interval, 6)
        for phase in PHASES
    }

    phase_hours = {phase: round(phase_seconds[phase] / 3600, 6) for phase in PHASES}
    phase_frequencies = {
        phase: frequency_per_hour(total_event_episodes_by_phase[phase], phase_seconds[phase])
        for phase in PHASES
    }

    return {
        "row_count": row_count,
        "sleep_stage_counts": dict(sleep_stage_counts),
        "sleep_phase_seconds": phase_seconds,
        "sleep_phase_hours": phase_hours,
        "event_value_counts": {
            column: dict(counts) for column, counts in event_value_counts.items()
        },
        "event_marked_row_counts": dict(event_marked_row_counts),
        "event_episode_counts": dict(event_episode_counts),
        "event_episode_counts_by_phase": {
            column: {phase: counts[phase] for phase in PHASES}
            for column, counts in event_episode_counts_by_phase.items()
        },
        "total_event_episodes": total_event_episodes,
        "total_event_episodes_by_phase": {
            phase: total_event_episodes_by_phase[phase] for phase in PHASES
        },
        "outside_sleep_event_episodes": outside_sleep_event_episodes,
        "events_per_hour_by_phase": phase_frequencies,
        "timestamp_first": timestamp_first,
        "timestamp_last": timestamp_last,
        "timestamp_step_seconds": sample_interval,
        "event_count_definition": (
            "Unique contiguous episodes in the union of the annotated event columns; "
            "per-column episode counts are reported independently."
        ),
    }


def make_result_row(subject: str, report: dict[str, Any]) -> dict[str, Any]:
    """Flatten the important results into one CSV row."""
    result: dict[str, Any] = {
        "subject": subject,
        "rem_hours": report["sleep_phase_hours"]["REM"],
        "nrem_hours": report["sleep_phase_hours"]["NREM"],
        "rem_total_events": report["total_event_episodes_by_phase"]["REM"],
        "nrem_total_events": report["total_event_episodes_by_phase"]["NREM"],
        "outside_sleep_total_events": report["outside_sleep_event_episodes"],
        "rem_events_per_hour": report["events_per_hour_by_phase"]["REM"],
        "nrem_events_per_hour": report["events_per_hour_by_phase"]["NREM"],
    }

    for column in EVENT_COLUMNS:
        counts = report["event_episode_counts_by_phase"].get(column, {})
        safe_name = column.lower()
        result[f"rem_{safe_name}_events"] = counts.get("REM", 0)
        result[f"nrem_{safe_name}_events"] = counts.get("NREM", 0)

    return result


def write_outputs(
    output_dir: Path, subject: str, report: dict[str, Any]
) -> tuple[Path, Path]:
    """Write one CSV result row and one detailed JSON report."""
    output_dir.mkdir(parents=True, exist_ok=True)
    csv_path = output_dir / f"{subject}_results.csv"
    json_path = output_dir / f"{subject}_summary.json"

    result_row = make_result_row(subject, report)
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(result_row))
        writer.writeheader()
        writer.writerow(result_row)

    with json_path.open("w", encoding="utf-8") as handle:
        json.dump({"subject": subject, **report}, handle, indent=2)
        handle.write("\n")

    return csv_path, json_path


def write_combined_results(output_dir: Path, result_rows: list[dict[str, Any]]) -> Path:
    """Write one table containing the important results for every subject."""
    if not result_rows:
        raise ValueError("There are no subject results to combine.")

    output_dir.mkdir(parents=True, exist_ok=True)
    combined_path = output_dir / "all_subjects_results.csv"
    with combined_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(result_rows[0]))
        writer.writeheader()
        writer.writerows(result_rows)

    return combined_path


def print_report(subject: str, report: dict[str, Any], csv_path: Path, json_path: Path) -> None:
    """Display the main results for the person running the program."""
    print(f"Subject: {subject}")
    print(f"Rows analyzed: {report['row_count']:,}")
    print()
    print("Sleep duration:")
    for phase in PHASES:
        print(
            f"  {phase}: {report['sleep_phase_hours'][phase]:.3f} hours "
            f"({report['sleep_phase_seconds'][phase]:,.3f} seconds)"
        )
    print()
    print("Respiratory event episodes:")
    for phase in PHASES:
        count = report["total_event_episodes_by_phase"][phase]
        frequency = report["events_per_hour_by_phase"][phase]
        print(f"  {phase}: {count:,} events; {frequency} events/hour")
    print(f"  Outside REM/NREM: {report['outside_sleep_event_episodes']:,} events")
    print()
    print("Results written to:")
    print(f"  {csv_path}")
    print(f"  {json_path}")


def run_single_subject(
    input_path: Path, subject: str, output_dir: Path
) -> dict[str, Any]:
    """Analyze one subject, save its files, and return its flattened result row."""
    report = analyze_csv(input_path)
    csv_path, json_path = write_outputs(output_dir, subject, report)
    print_report(subject, report, csv_path, json_path)
    return make_result_row(subject, report)


def run_batch(
    input_dir: Path,
    subjects: list[str],
    output_dir: Path,
    file_suffix: str = "_whole_df.csv",
) -> None:
    """Analyze several subjects and save a combined comparison table."""
    result_rows: list[dict[str, Any]] = []

    for subject in subjects:
        input_path = input_dir / f"{subject}{file_suffix}"
        if not input_path.is_file():
            raise FileNotFoundError(f"Input file does not exist: {input_path}")
        result_rows.append(run_single_subject(input_path, subject, output_dir))

    combined_path = write_combined_results(output_dir, result_rows)
    print()
    print(f"Combined results for {len(result_rows)} subjects written to:")
    print(f"  {combined_path}")


def main() -> None:
    """Run either the single-subject or batch analysis."""
    args = parse_args()
    if args.input is not None:
        if not args.subject:
            raise SystemExit("Single-file mode requires --subject.")
        run_single_subject(args.input, args.subject, args.output_dir)
    else:
        if args.subject:
            raise SystemExit("Do not use --subject together with --input-dir; use --subjects instead.")
        run_batch(args.input_dir, args.subjects, args.output_dir, args.file_suffix)


if __name__ == "__main__":
    main()
