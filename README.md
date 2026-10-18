# Snowflake Automated HR Data Pipeline

An end-to-end automated data ingestion and orchestration pipeline built in Snowflake to transform and load HR data from JSON payloads.

## Project Overview
This project implements a relational database model (`DMT_RH`) and sets up an automated ingestion flow for semi-structured JSON data into Snowflake using native features like Internal Stages, File Formats, Snowpipes, and Task Orchestration.

## Data Model & Schema
The database contains 4 interconnected entities:
- **`departement`**: Department details, locations, and head responsibilities.
- **`poste`**: Job titles, compensation levels, and base salary mappings.
- **`employe`**: Employee profiles with dynamic corporate email generation.
- **`contrat`**: Contract details with automated conditional status tracking.

## Architecture & Features
- **Relational Integrity**: Built tables with Primary Keys, Auto-Incrementing Sequences, and Foreign Key constraints.
- **Semi-Structured Ingestion**: Configured an Internal Stage (`Stage_RH`) and JSON File Format (`json_format`) with outer array stripping.
- **Data Transformation on Ingestion**: Built 4 distinct **Snowpipes** applying automated business rules:
  - **Corporate Email**: Formatted as `Upper(1st letter of Surname) + Lower(First Name) + @RH.fr`.
  - **Contract Status**: Evaluates active contracts based on termination dates (`Active` or `NULL`).
- **Orchestration**: Configured a hierarchical **Tasks** graph (`AFTER` clause) to maintain parent-child table load order and respect foreign key dependencies.

## Tech Stack
- **Platform**: Snowflake
- **Language**: SQL
- **Core Features**: Internal Stage, File Formats, Snowpipe, Snowflake Tasks, JSON Parsing

## Repository Structure
- `snowflake_rh_pipeline.sql`: Full SQL script containing DDL for Database, Schema, Tables, Stage, File Format, Snowpipes, and Task Orchestration.