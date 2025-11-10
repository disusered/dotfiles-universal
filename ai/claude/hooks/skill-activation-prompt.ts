import { readFileSync } from 'fs';
import { join } from 'path';

interface HookInput {
  sessionId: string;
  transcriptPath: string;
  workingDir: string;
  permissionMode: string;
  prompt: string;
}

interface SkillRule {
  type: 'domain' | 'tool' | 'guardrail';
  enforcement: 'block' | 'suggest' | 'warn';
  priority: 'critical' | 'high' | 'medium' | 'low';
  description: string;
  triggers: {
    promptTriggers?: {
      keywords?: string[];
      intentPatterns?: string[];
    };
    fileTriggers?: {
      pathPatterns?: string[];
      contentPatterns?: string[];
    };
  };
}

interface SkillRules {
  version: string;
  skills: Record<string, SkillRule>;
}

interface MatchedSkill {
  name: string;
  rule: SkillRule;
  matchType: 'keyword' | 'intent';
}

async function main() {
  try {
    // Read stdin
    const input = readFileSync(0, 'utf-8');
    const hookInput: HookInput = JSON.parse(input);

    // Load skill rules
    const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
    const rulesPath = join(projectDir, 'ai', 'claude', 'skills', 'skill-rules.json');

    let skillRules: SkillRules;
    try {
      const rulesContent = readFileSync(rulesPath, 'utf-8');
      skillRules = JSON.parse(rulesContent);
    } catch (error) {
      // No skill rules file, exit silently
      process.exit(0);
    }

    // Match skills against prompt
    const matches: MatchedSkill[] = [];
    const prompt = hookInput.prompt.toLowerCase();

    for (const [skillName, rule] of Object.entries(skillRules.skills)) {
      const triggers = rule.triggers.promptTriggers;
      if (!triggers) continue;

      // Check keywords
      if (triggers.keywords) {
        for (const keyword of triggers.keywords) {
          if (prompt.includes(keyword.toLowerCase())) {
            matches.push({ name: skillName, rule, matchType: 'keyword' });
            break;
          }
        }
      }

      // Check intent patterns
      if (triggers.intentPatterns) {
        for (const pattern of triggers.intentPatterns) {
          const regex = new RegExp(pattern, 'i');
          if (regex.test(prompt)) {
            // Avoid duplicates
            if (!matches.find(m => m.name === skillName)) {
              matches.push({ name: skillName, rule, matchType: 'intent' });
            }
            break;
          }
        }
      }
    }

    // If no matches, exit
    if (matches.length === 0) {
      process.exit(0);
    }

    // Group by priority
    const byPriority: Record<string, MatchedSkill[]> = {
      critical: [],
      high: [],
      medium: [],
      low: []
    };

    for (const match of matches) {
      byPriority[match.rule.priority].push(match);
    }

    // Generate output
    console.log('## Detected Relevant Skills\n');

    for (const priority of ['critical', 'high', 'medium', 'low'] as const) {
      const skills = byPriority[priority];
      if (skills.length === 0) continue;

      const label = {
        critical: 'Critical (Required)',
        high: 'High Priority (Recommended)',
        medium: 'Medium Priority (Suggested)',
        low: 'Low Priority (Optional)'
      }[priority];

      console.log(`### ${label}\n`);
      for (const skill of skills) {
        console.log(`**${skill.name}** - ${skill.rule.description}`);
        console.log(`  - Type: ${skill.rule.type}`);
        console.log(`  - Match: ${skill.matchType}\n`);
      }
    }

    console.log('\n**Action Required:**');
    console.log('Consider using the Skill tool to load the appropriate skill(s) before responding.');
    console.log('Example: Use the Skill tool with command "work-journal" if you need to generate PR descriptions or summaries.\n');

  } catch (error) {
    // Silent failure - hooks should not break the main workflow
    process.exit(0);
  }
}

main();
