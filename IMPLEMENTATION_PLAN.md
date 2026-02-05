# AIControl → Claude Code Skill: Implementation Plan

## Executive Summary

Transform AIControl from a SwiftUI app with LLM intermediary into a direct Claude Code skill that gives Claude (me) native computer control with NO intermediate LLM.

### Key Changes
- **Remove**: All LLM provider code (Anthropic, OpenAI, Gemini, Grok)
- **Add**: CLI interface using ArgumentParser
- **Add**: MCP server wrapper for Claude Code integration
- **Keep**: All screen capture and input control logic (90% reuse)

### Architecture
```
Claude Code (me)
    ↓ [MCP Protocol]
MCP Server (Node.js wrapper)
    ↓ [Spawn process]
Swift CLI Tool (aicontrol)
    ↓ [Native APIs]
macOS (ScreenCaptureKit, CGEvent)
```

---

## Core Decisions

### 1. Coordinate System: Display Points Only
- Screenshots captured at display point resolution (e.g., 1920x1200 for retina)
- Click coordinates match screenshot pixel coordinates 1:1
- No scaling math needed - perfect alignment
- Existing code already uses display points

### 2. Screen Capture: On-Demand Screenshots
- Claude requests screenshot when needed
- Full-resolution PNG to /tmp
- Metadata: cursor position, display size, timestamp
- Optional grid overlay for visual reference

### 3. Interface: CLI + MCP Hybrid
- Swift CLI tool with subcommands
- MCP server wraps CLI for Claude Code
- Both standalone and integrated usage supported

---

## Implementation Phases

### Phase 1: Setup ✓
- [x] Analyze original requirements
- [x] Create detailed implementation plan
- [ ] Review and approve plan

### Phase 2: CLI Interface (Est: 2-3 hours)
**Goal**: Create Swift CLI tool with all commands

Tasks:
- [ ] Create `Sources/AIControlCLI/` directory structure
- [ ] Add ArgumentParser dependency to Package.swift
- [ ] Implement `main.swift` with CommandConfiguration
- [ ] Create command files:
  - [ ] CaptureCommand.swift
  - [ ] ClickCommand.swift
  - [ ] TypeCommand.swift
  - [ ] KeyCommand.swift
  - [ ] ScrollCommand.swift
  - [ ] DragCommand.swift
  - [ ] CalibrationCommand.swift
  - [ ] StatusCommand.swift
- [ ] Create JSONOutput.swift for result serialization
- [ ] Test: `swift run AIControlCLI capture`

### Phase 3: Screen Capture (Est: 1-2 hours)
**Goal**: Screenshot capture with metadata

Tasks:
- [ ] Refactor ScreenCaptureService for CLI use
- [ ] Implement PNG saving with optional grid overlay
- [ ] Add display info collection
- [ ] Add cursor position detection
- [ ] Test: Verify screenshot accuracy and metadata

### Phase 4: Input Control (Est: 1 hour)
**Goal**: All input commands working

Tasks:
- [ ] Wire up InputControlService to each command
- [ ] Implement click, right-click, double-click
- [ ] Implement type, press_key with modifier parsing
- [ ] Implement scroll, drag
- [ ] Add coordinate validation
- [ ] Test: Execute each command and verify

### Phase 5: Calibration (Est: 1 hour)
**Goal**: Coordinate accuracy validation

Tasks:
- [ ] Implement CalibrationCommand using existing logic
- [ ] Add multi-point test (center + 4 corners)
- [ ] Calculate average and max error
- [ ] Output pass/fail with metrics
- [ ] Test: Run on main display, verify < 5px error

### Phase 6: MCP Server (Est: 2-3 hours)
**Goal**: Claude Code integration

Tasks:
- [ ] Create `mcp-server/` directory
- [ ] Initialize Node.js project with MCP SDK
- [ ] Implement MCP server in TypeScript
- [ ] Define all tools (capture_screen, click, type, etc.)
- [ ] Add CLI spawning and JSON parsing
- [ ] Add temp file management
- [ ] Create skill.json manifest
- [ ] Test: Run MCP server, verify tool invocation

### Phase 7: Testing & Refinement (Est: 2-4 hours)
**Goal**: Validate entire system

Tasks:
- [ ] Create test suite for CLI
- [ ] Test MCP integration in Claude Code
- [ ] Run end-to-end scenarios
- [ ] Performance benchmarking
- [ ] Bug fixes and edge cases
- [ ] Documentation updates

---

## Commands to Implement

```bash
# Screen capture
aicontrol capture [--grid] [--output PATH]

# Mouse control
aicontrol click <x> <y>
aicontrol right-click <x> <y>
aicontrol double-click <x> <y>
aicontrol move-mouse <x> <y>
aicontrol drag <fx> <fy> <tx> <ty>
aicontrol scroll <dx> <dy>

# Keyboard control
aicontrol type <text>
aicontrol key <key> [--modifiers cmd,shift]

# Application control
aicontrol open-app <name>
aicontrol focus-app <name>
aicontrol show-desktop

# Calibration & debugging
aicontrol calibrate
aicontrol status
```

---

## Success Criteria

### Functional Requirements
- ✓ CLI tool compiles and runs
- ✓ Screen capture returns PNG with metadata
- ✓ All input commands execute successfully
- ✓ Calibration shows < 5px average error
- ✓ MCP server exposes all tools
- ✓ Claude Code can invoke tools and receive results

### Performance Requirements
- Screen capture: < 50ms
- Click execution: < 1ms
- Calibration: < 2 seconds

### Quality Requirements
- Proper error handling with JSON output
- Permission checks with clear error messages
- Clean code with proper separation of concerns
- Comprehensive testing coverage

---

## Key Files to Modify

### Create New
- `Sources/AIControlCLI/main.swift` - CLI entry point
- `Sources/AIControlCLI/Commands/*.swift` - All command implementations
- `Sources/AIControlCLI/Output/JSONOutput.swift` - Result serialization
- `mcp-server/src/index.ts` - MCP server implementation
- `skill.json` - Claude Code skill manifest
- `install.sh` - Installation script

### Modify Existing
- `Package.swift` - Add CLI target and ArgumentParser dependency
- `Sources/AIControl/Services/ScreenCaptureService.swift` - Make CLI-friendly
- `Sources/AIControl/Services/InputControlService.swift` - Expose for CLI

### Archive/Remove (Phase 2)
- `Sources/AIControl/Models/LLMProvider.swift`
- `Sources/AIControl/Models/*Provider.swift`
- `Sources/AIControl/Services/SessionManager.swift`
- `Sources/AIControl/Services/ActionParser.swift`
- `Sources/AIControl/Utilities/ActionSystemPrompt.swift`

---

## Risk Mitigation

### Risk 1: Coordinate Misalignment
**Mitigation**: Built-in calibration command, always use display points

### Risk 2: Permission Issues
**Mitigation**: Clear error messages, status command, installation guide

### Risk 3: Multi-Display Confusion
**Mitigation**: Default to main display, document limitation

### Risk 4: Performance Degradation
**Mitigation**: Reuse optimized capture code, benchmark all commands

---

## Next Steps

1. **Review this plan** - Confirm approach is correct
2. **Delete unnecessary code** - Clean slate for new implementation
3. **Start Phase 2** - Create CLI interface using multiple agents in parallel
4. **Test incrementally** - Validate each phase before moving to next
5. **Iterate until perfect** - Bug fix cycles until < 5px calibration error

---

## Timeline Estimate

- Phase 2-4 (CLI + Core Features): 4-6 hours
- Phase 5-6 (Calibration + MCP): 3-4 hours
- Phase 7 (Testing + Refinement): 2-4 hours

**Total**: 9-14 hours of implementation + testing

---

## Questions for User

1. Should we keep the SwiftUI app for debugging, or remove it entirely?
2. Should we support multi-display from the start, or document as future enhancement?
3. Any specific coordinate accuracy requirements beyond < 5px?
4. Should calibration run automatically on first use, or manual-only?

