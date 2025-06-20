/**
 * Roadmap Parser for Claude Code
 * Parses and manipulates ROADMAP.md files
 */

export interface RoadmapItem {
  id: string;
  title: string;
  description: string;
  status: 'completed' | 'in-progress' | 'planned';
  priority: 'high' | 'medium' | 'low';
  effort: 'high' | 'medium' | 'low';
  impact: 'high' | 'medium' | 'low';
  dependencies: string[];
  section: string;
  tasks: string[];
}

export interface RoadmapSection {
  title: string;
  items: RoadmapItem[];
}

export interface Roadmap {
  sections: RoadmapSection[];
  lastUpdated: string;
}

export class RoadmapParser {
  private content: string;
  private roadmap: Roadmap;

  constructor(content: string) {
    this.content = content;
    this.roadmap = this.parse();
  }

  private parse(): Roadmap {
    const sections: RoadmapSection[] = [];
    const lines = this.content.split('\n');
    
    let currentSection: RoadmapSection | null = null;
    let currentItem: RoadmapItem | null = null;
    
    for (const line of lines) {
      // Section headers (## or ###)
      if (line.match(/^#{2,3}\s+/)) {
        if (currentItem && currentSection) {
          currentSection.items.push(currentItem);
          currentItem = null;
        }
        
        if (currentSection) {
          sections.push(currentSection);
        }
        
        currentSection = {
          title: line.replace(/^#{2,3}\s+/, '').trim(),
          items: []
        };
      }
      
      // Feature items (#### headers)
      else if (line.match(/^#{4}\s+/)) {
        if (currentItem && currentSection) {
          currentSection.items.push(currentItem);
        }
        
        const title = line.replace(/^#{4}\s+/, '').trim();
        currentItem = {
          id: this.generateId(title),
          title,
          description: '',
          status: this.inferStatus(currentSection?.title || ''),
          priority: this.extractPriority(title),
          effort: 'medium',
          impact: 'medium',
          dependencies: [],
          section: currentSection?.title || '',
          tasks: []
        };
      }
      
      // Task items (- [ ] or - [x])
      else if (line.match(/^-\s+\[([ x])\]/)) {
        const isCompleted = line.includes('[x]');
        const task = line.replace(/^-\s+\[([ x])\]\s+/, '').trim();
        
        if (currentItem) {
          currentItem.tasks.push(task);
        }
      }
      
      // Description lines
      else if (line.trim().startsWith('*') && currentItem) {
        currentItem.description = line.replace(/^\*/, '').trim();
      }
      
      // Metadata lines (Impact, Effort, Dependencies)
      else if (line.includes('**Impact:**') && currentItem) {
        currentItem.impact = this.extractMetadata(line, 'Impact') as any;
        currentItem.effort = this.extractMetadata(line, 'Effort') as any;
      }
    }
    
    // Add final items
    if (currentItem && currentSection) {
      currentSection.items.push(currentItem);
    }
    if (currentSection) {
      sections.push(currentSection);
    }
    
    return {
      sections,
      lastUpdated: this.extractLastUpdated()
    };
  }

  private generateId(title: string): string {
    return title.toLowerCase()
      .replace(/[^a-z0-9\s]/g, '')
      .replace(/\s+/g, '-')
      .substring(0, 50);
  }

  private inferStatus(sectionTitle: string): 'completed' | 'in-progress' | 'planned' {
    if (sectionTitle.includes('Completed') || sectionTitle.includes('✅')) {
      return 'completed';
    }
    if (sectionTitle.includes('In Progress') || sectionTitle.includes('🚧')) {
      return 'in-progress';
    }
    return 'planned';
  }

  private extractPriority(title: string): 'high' | 'medium' | 'low' {
    if (title.includes('⭐') || title.includes('High Priority')) {
      return 'high';
    }
    if (title.includes('🌟') || title.includes('Medium Priority')) {
      return 'medium';
    }
    return 'low';
  }

  private extractMetadata(line: string, key: string): string {
    const regex = new RegExp(`\\*\\*${key}:\\*\\*\\s+(\\w+)`, 'i');
    const match = line.match(regex);
    return match ? match[1].toLowerCase() : 'medium';
  }

  private extractLastUpdated(): string {
    const match = this.content.match(/\*Last Updated:\s*([^*]+)\*/);
    return match ? match[1].trim() : new Date().toISOString().split('T')[0];
  }

  // Public API methods
  public getRoadmap(): Roadmap {
    return this.roadmap;
  }

  public getSection(name: string): RoadmapSection | null {
    return this.roadmap.sections.find(s => 
      s.title.toLowerCase().includes(name.toLowerCase())
    ) || null;
  }

  public getItem(id: string): RoadmapItem | null {
    for (const section of this.roadmap.sections) {
      const item = section.items.find(i => i.id === id || i.title === id);
      if (item) return item;
    }
    return null;
  }

  public getByStatus(status: 'completed' | 'in-progress' | 'planned'): RoadmapItem[] {
    const items: RoadmapItem[] = [];
    for (const section of this.roadmap.sections) {
      items.push(...section.items.filter(i => i.status === status));
    }
    return items;
  }

  public getByPriority(priority: 'high' | 'medium' | 'low'): RoadmapItem[] {
    const items: RoadmapItem[] = [];
    for (const section of this.roadmap.sections) {
      items.push(...section.items.filter(i => i.priority === priority));
    }
    return items;
  }

  public getAnalytics() {
    const allItems = this.roadmap.sections.flatMap(s => s.items);
    
    return {
      total: allItems.length,
      completed: allItems.filter(i => i.status === 'completed').length,
      inProgress: allItems.filter(i => i.status === 'in-progress').length,
      planned: allItems.filter(i => i.status === 'planned').length,
      highPriority: allItems.filter(i => i.priority === 'high').length,
      completionRate: allItems.length > 0 ? 
        (allItems.filter(i => i.status === 'completed').length / allItems.length * 100).toFixed(1) + '%' : '0%'
    };
  }

  public addItem(item: Partial<RoadmapItem>, sectionName: string): void {
    const section = this.getSection(sectionName);
    if (!section) {
      throw new Error(`Section "${sectionName}" not found`);
    }

    const newItem: RoadmapItem = {
      id: this.generateId(item.title || 'new-item'),
      title: item.title || 'New Item',
      description: item.description || '',
      status: item.status || 'planned',
      priority: item.priority || 'medium',
      effort: item.effort || 'medium',
      impact: item.impact || 'medium',
      dependencies: item.dependencies || [],
      section: sectionName,
      tasks: item.tasks || []
    };

    section.items.push(newItem);
  }

  public updateItem(id: string, updates: Partial<RoadmapItem>): boolean {
    const item = this.getItem(id);
    if (!item) return false;

    Object.assign(item, updates);
    return true;
  }

  public completeItem(id: string): boolean {
    return this.updateItem(id, { status: 'completed' });
  }

  public exportToMarkdown(): string {
    // This would regenerate the markdown from the parsed roadmap
    // Implementation would rebuild the original format
    return this.content; // Simplified for now
  }

  public exportToJSON(): string {
    return JSON.stringify(this.roadmap, null, 2);
  }
}