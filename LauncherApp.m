#import <Cocoa/Cocoa.h>

@interface LauncherAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NSPopUpButton *projectPopup;
@property (nonatomic, strong) NSComboBox *commandComboBox;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *pinButton;
@property (nonatomic, strong) NSButton *removeButton;
@property (nonatomic, strong) NSButton *revealButton;
@property (nonatomic, strong) NSButton *launchButton;
@property (nonatomic, strong) NSMutableArray<NSString *> *rootFolders;
@property (nonatomic, strong) NSMutableArray<NSString *> *recentProjects;
@property (nonatomic, strong) NSMutableArray<NSString *> *pinnedProjects;
@property (nonatomic, strong) NSMutableArray<NSString *> *customCommands;
@property (nonatomic, copy) NSString *lastCommand;
@property (nonatomic, copy) NSString *selectedProject;
@end

@implementation LauncherAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [self loadConfig];
    [self buildMainMenu];
    [self buildWindow];
    [self refreshProjectMenuPreferSelection:nil];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (NSString *)configDirectory {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/ai-code-launcher"];
}

- (NSString *)configPath {
    return [[self configDirectory] stringByAppendingPathComponent:@"config.json"];
}

- (NSArray<NSString *> *)dedupeExistingDirectories:(NSArray<NSString *> *)paths {
    NSMutableOrderedSet<NSString *> *result = [NSMutableOrderedSet orderedSet];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    for (NSString *rawPath in paths) {
        NSString *path = [rawPath stringByExpandingTildeInPath];
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
            [result addObject:path];
        }
    }

    return result.array;
}

- (NSString *)normalizedCommand:(NSString *)command fallback:(NSString *)fallback {
    NSString *trimmed = [(command ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0 ? trimmed : fallback;
}

- (void)loadConfig {
    self.rootFolders = [NSMutableArray array];
    self.recentProjects = [NSMutableArray array];
    self.pinnedProjects = [NSMutableArray array];
    self.customCommands = [NSMutableArray array];
    self.lastCommand = @"codex";

    NSData *data = [NSData dataWithContentsOfFile:[self configPath]];
    if (!data) {
        return;
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![object isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSDictionary *config = (NSDictionary *)object;
    NSArray *roots = [config[@"rootFolders"] isKindOfClass:[NSArray class]] ? config[@"rootFolders"] : @[];
    NSArray *recent = [config[@"recentProjects"] isKindOfClass:[NSArray class]] ? config[@"recentProjects"] : @[];
    NSArray *pinned = [config[@"pinnedProjects"] isKindOfClass:[NSArray class]] ? config[@"pinnedProjects"] : @[];
    NSArray *customCommands = [config[@"customCommands"] isKindOfClass:[NSArray class]] ? config[@"customCommands"] : @[];
    NSString *lastCommand = [config[@"lastCommand"] isKindOfClass:[NSString class]] ? config[@"lastCommand"] : nil;
    NSDictionary *legacyCommands = [config[@"commands"] isKindOfClass:[NSDictionary class]] ? config[@"commands"] : @{};

    [self.rootFolders addObjectsFromArray:[self dedupeExistingDirectories:roots]];
    [self.recentProjects addObjectsFromArray:[self dedupeExistingDirectories:recent]];
    [self.pinnedProjects addObjectsFromArray:[self dedupeExistingDirectories:pinned]];
    for (id item in customCommands) {
        if ([item isKindOfClass:[NSString class]]) {
            NSString *normalized = [self normalizedCommand:item fallback:@""];
            if (normalized.length > 0 && ![self.customCommands containsObject:normalized]) {
                [self.customCommands addObject:normalized];
            }
        }
    }

    if (lastCommand.length > 0) {
        self.lastCommand = [self normalizedCommand:lastCommand fallback:@"codex"];
    } else if ([legacyCommands[@"codex"] isKindOfClass:[NSString class]]) {
        self.lastCommand = [self normalizedCommand:legacyCommands[@"codex"] fallback:@"codex"];
    }
}

- (void)saveConfig {
    [[NSFileManager defaultManager] createDirectoryAtPath:[self configDirectory]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSDictionary *config = @{
        @"rootFolders": [self dedupeExistingDirectories:self.rootFolders],
        @"recentProjects": [self dedupeExistingDirectories:self.recentProjects],
        @"pinnedProjects": [self dedupeExistingDirectories:self.pinnedProjects],
        @"customCommands": self.customCommands ?: @[],
        @"lastCommand": [self normalizedCommand:self.lastCommand fallback:@"codex"],
    };

    NSData *data = [NSJSONSerialization dataWithJSONObject:config options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:[self configPath] atomically:YES];
}

- (NSArray<NSString *> *)defaultCommandChoices {
    return @[
        @"codex",
        @"claude code",
        @"opencode",
    ];
}

- (NSArray<NSString *> *)allCommandChoices {
    NSMutableOrderedSet<NSString *> *choices = [NSMutableOrderedSet orderedSet];
    [choices addObjectsFromArray:[self defaultCommandChoices]];
    [choices addObjectsFromArray:self.customCommands];
    return choices.array;
}

- (void)buildMainMenu {
    NSMenu *menuBar = [[NSMenu alloc] init];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [menuBar addItem:appMenuItem];
    [NSApp setMainMenu:menuBar];

    NSMenu *appMenu = [[NSMenu alloc] init];
    NSString *appName = NSProcessInfo.processInfo.processName ?: @"AI Code Launcher";

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"退出 %@", appName]
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];
    [appMenu addItem:quitItem];
    [appMenuItem setSubmenu:appMenu];
}

- (void)refreshCommandChoices {
    NSArray<NSString *> *choices = [self allCommandChoices];
    [self.commandComboBox removeAllItems];
    [self.commandComboBox addItemsWithObjectValues:choices];
    NSString *current = [self normalizedCommand:self.lastCommand fallback:@"codex"];
    self.commandComboBox.stringValue = current;
}

- (NSArray<NSString *> *)allProjects {
    NSMutableOrderedSet<NSString *> *projects = [NSMutableOrderedSet orderedSet];
    [projects addObjectsFromArray:self.pinnedProjects];
    [projects addObjectsFromArray:self.recentProjects];
    for (NSString *rootPath in self.rootFolders) {
        [projects addObjectsFromArray:[self subdirectoriesForRoot:rootPath]];
    }
    return projects.array;
}

- (NSString *)rootFolderContainingProject:(NSString *)projectPath {
    NSString *bestMatch = nil;
    for (NSString *rootPath in self.rootFolders) {
        if ([projectPath isEqualToString:rootPath]) {
            if (bestMatch == nil || rootPath.length > bestMatch.length) {
                bestMatch = rootPath;
            }
            continue;
        }

        NSString *prefix = [rootPath stringByAppendingString:@"/"];
        if ([projectPath hasPrefix:prefix]) {
            if (bestMatch == nil || rootPath.length > bestMatch.length) {
                bestMatch = rootPath;
            }
        }
    }
    return bestMatch;
}

- (BOOL)shouldSkipDirectoryNamed:(NSString *)name {
    static NSSet<NSString *> *excludedNames;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        excludedNames = [NSSet setWithArray:@[
            @".git",
            @".idea",
            @".vscode",
            @".venv",
            @"node_modules",
            @"dist",
            @"build",
            @"__pycache__",
            @"venv",
        ]];
    });
    return [name hasPrefix:@"."] || [excludedNames containsObject:name];
}

- (NSArray<NSString *> *)subdirectoriesForRoot:(NSString *)rootPath {
    NSMutableOrderedSet<NSString *> *results = [NSMutableOrderedSet orderedSet];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *rootURL = [NSURL fileURLWithPath:rootPath isDirectory:YES];
    NSArray<NSURLResourceKey> *keys = @[NSURLIsDirectoryKey, NSURLNameKey, NSURLIsPackageKey];
    NSDirectoryEnumerator<NSURL *> *enumerator = [fileManager enumeratorAtURL:rootURL
                                                   includingPropertiesForKeys:keys
                                                                      options:(NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants)
                                                                 errorHandler:nil];

    for (NSURL *url in enumerator) {
        NSNumber *isDirectory = nil;
        NSString *name = nil;
        NSNumber *isPackage = nil;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        [url getResourceValue:&name forKey:NSURLNameKey error:nil];
        [url getResourceValue:&isPackage forKey:NSURLIsPackageKey error:nil];

        if ([self shouldSkipDirectoryNamed:name ?: @""]) {
            [enumerator skipDescendants];
            continue;
        }

        if (![isDirectory boolValue]) {
            continue;
        }

        if ([isPackage boolValue]) {
            [enumerator skipDescendants];
            continue;
        }

        [results addObject:url.path];
    }

    return results.array;
}

- (NSString *)displayNameForPath:(NSString *)path {
    NSString *name = path.lastPathComponent;
    return name.length > 0 ? name : path;
}

- (NSString *)shortDisplayPath:(NSString *)path maxLength:(NSUInteger)maxLength {
    NSString *displayPath = [path stringByExpandingTildeInPath];
    NSString *home = NSHomeDirectory();
    if ([displayPath hasPrefix:home]) {
        displayPath = [@"~" stringByAppendingString:[displayPath substringFromIndex:home.length]];
    }

    if (displayPath.length <= maxLength) {
        return displayPath;
    }

    NSUInteger headLength = MIN(18, maxLength / 3);
    NSUInteger tailLength = MIN(32, maxLength - headLength - 3);
    if (displayPath.length <= headLength + tailLength + 3) {
        return displayPath;
    }

    NSString *head = [displayPath substringToIndex:headLength];
    NSString *tail = [displayPath substringFromIndex:displayPath.length - tailLength];
    return [NSString stringWithFormat:@"%@...%@", head, tail];
}

- (NSString *)projectMenuTitleForPath:(NSString *)project {
    NSString *mark = [self.pinnedProjects containsObject:project] ? @"★ " : @"";
    NSString *name = [self displayNameForPath:project];
    NSString *parentPath = [self shortDisplayPath:[project stringByDeletingLastPathComponent] maxLength:34];
    return [NSString stringWithFormat:@"%@%@  ·  %@", mark, name, parentPath];
}

- (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text font:(NSFont *)font {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text ?: @"";
    label.font = font;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.editable = NO;
    label.selectable = NO;
    return label;
}

- (NSButton *)buttonWithFrame:(NSRect)frame title:(NSString *)title action:(SEL)action {
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    button.title = title;
    button.target = self;
    button.action = action;
    button.bezelStyle = NSBezelStyleRounded;
    return button;
}

- (NSColor *)accentColor {
    return [NSColor colorWithSRGBRed:0.94 green:0.43 blue:0.18 alpha:1.0];
}

- (NSColor *)accentGlowColor {
    return [NSColor colorWithSRGBRed:0.96 green:0.57 blue:0.24 alpha:0.24];
}

- (NSColor *)panelFillColor {
    return [NSColor colorWithSRGBRed:0.97 green:0.98 blue:0.99 alpha:0.78];
}

- (NSColor *)panelBorderColor {
    return [NSColor colorWithSRGBRed:0.82 green:0.86 blue:0.90 alpha:0.95];
}

- (NSView *)cardViewWithFrame:(NSRect)frame backgroundColor:(NSColor *)backgroundColor borderColor:(NSColor *)borderColor cornerRadius:(CGFloat)cornerRadius {
    NSView *card = [[NSView alloc] initWithFrame:frame];
    card.wantsLayer = YES;
    card.layer.cornerRadius = cornerRadius;
    card.layer.backgroundColor = backgroundColor.CGColor;
    card.layer.borderWidth = borderColor ? 1.0 : 0.0;
    card.layer.borderColor = borderColor.CGColor;
    return card;
}

- (void)styleSecondaryButton:(NSButton *)button {
    button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    button.bezelStyle = NSBezelStyleRounded;
    button.bezelColor = [NSColor colorWithSRGBRed:0.94 green:0.95 blue:0.97 alpha:1.0];
    button.contentTintColor = [NSColor colorWithSRGBRed:0.19 green:0.24 blue:0.30 alpha:1.0];
}

- (void)stylePrimaryButton:(NSButton *)button {
    button.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    button.bezelStyle = NSBezelStyleRounded;
    button.bezelColor = [self accentColor];
    button.contentTintColor = NSColor.whiteColor;
}

- (void)styleInputControl:(NSView *)view {
    view.wantsLayer = YES;
    view.layer.cornerRadius = 12.0;
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = [self panelBorderColor].CGColor;
    view.layer.backgroundColor = [NSColor colorWithSRGBRed:1.0 green:1.0 blue:1.0 alpha:0.96].CGColor;
}

- (void)buildWindow {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 590, 500)
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window center];
    self.window.title = @"AI Code Launcher";
    self.window.minSize = NSMakeSize(560, 470);
    self.window.delegate = self;
    self.window.titlebarAppearsTransparent = YES;
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.movableByWindowBackground = YES;

    NSVisualEffectView *backgroundView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 590, 500)];
    backgroundView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    backgroundView.material = NSVisualEffectMaterialSidebar;
    backgroundView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    backgroundView.state = NSVisualEffectStateActive;
    backgroundView.wantsLayer = YES;
    backgroundView.layer.backgroundColor = [NSColor colorWithSRGBRed:0.93 green:0.95 blue:0.97 alpha:0.96].CGColor;
    self.window.contentView = backgroundView;

    NSView *contentView = self.window.contentView;

    NSView *glowLarge = [self cardViewWithFrame:NSMakeRect(396, 368, 180, 180)
                                backgroundColor:[self accentGlowColor]
                                     borderColor:nil
                                    cornerRadius:90.0];
    glowLarge.alphaValue = 0.85;

    NSView *glowSmall = [self cardViewWithFrame:NSMakeRect(12, 420, 120, 120)
                                backgroundColor:[[NSColor colorWithSRGBRed:0.18 green:0.50 blue:0.98 alpha:1.0] colorWithAlphaComponent:0.14]
                                     borderColor:nil
                                    cornerRadius:60.0];
    glowSmall.alphaValue = 0.9;

    NSView *heroCard = [self cardViewWithFrame:NSMakeRect(24, 378, 542, 96)
                                backgroundColor:[NSColor colorWithSRGBRed:0.13 green:0.17 blue:0.23 alpha:0.95]
                                     borderColor:[NSColor colorWithSRGBRed:0.25 green:0.31 blue:0.38 alpha:1.0]
                                    cornerRadius:22.0];

    NSTextField *badgeLabel = [self labelWithFrame:NSMakeRect(18, 62, 110, 18) text:@"Launchpad" font:[NSFont systemFontOfSize:11 weight:NSFontWeightSemibold]];
    badgeLabel.textColor = [[self accentColor] blendedColorWithFraction:0.15 ofColor:NSColor.whiteColor];

    NSTextField *titleLabel = [self labelWithFrame:NSMakeRect(18, 28, 320, 30) text:@"AI Code Launcher" font:[NSFont systemFontOfSize:28 weight:NSFontWeightHeavy]];
    titleLabel.textColor = NSColor.whiteColor;

    NSTextField *subtitleLabel = [self labelWithFrame:NSMakeRect(18, 10, 360, 18) text:@"找目录、切目录、选命令，直接开工。" font:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];
    subtitleLabel.textColor = [NSColor colorWithSRGBRed:0.79 green:0.84 blue:0.90 alpha:1.0];

    NSTextField *heroHint = [self labelWithFrame:NSMakeRect(360, 28, 158, 40) text:@"Projects\nCommand\nLaunch" font:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightSemibold]];
    heroHint.textColor = [NSColor colorWithSRGBRed:0.98 green:0.72 blue:0.54 alpha:0.95];
    heroHint.alignment = NSTextAlignmentRight;

    NSView *projectCard = [self cardViewWithFrame:NSMakeRect(24, 198, 542, 158)
                                   backgroundColor:[self panelFillColor]
                                        borderColor:[self panelBorderColor]
                                       cornerRadius:22.0];
    NSTextField *projectLabel = [self labelWithFrame:NSMakeRect(18, 126, 120, 20) text:@"项目目录" font:[NSFont systemFontOfSize:13 weight:NSFontWeightBold]];
    projectLabel.textColor = [NSColor colorWithSRGBRed:0.17 green:0.21 blue:0.27 alpha:1.0];
    NSTextField *projectHint = [self labelWithFrame:NSMakeRect(98, 126, 260, 18) text:@"收藏、移除、Finder 跳转都集中在这里。" font:[NSFont systemFontOfSize:12]];
    projectHint.textColor = NSColor.secondaryLabelColor;

    self.projectPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(18, 88, 506, 34) pullsDown:NO];
    self.projectPopup.target = self;
    self.projectPopup.action = @selector(projectSelectionChanged:);
    self.projectPopup.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [self styleInputControl:self.projectPopup];

    NSButton *chooseButton = [self buttonWithFrame:NSMakeRect(18, 46, 242, 30) title:@"选择文件夹..." action:@selector(chooseFolder:)];
    self.revealButton = [self buttonWithFrame:NSMakeRect(282, 46, 242, 30) title:@"在 Finder 中显示" action:@selector(revealInFinder:)];
    self.pinButton = [self buttonWithFrame:NSMakeRect(18, 12, 242, 30) title:@"收藏当前项目" action:@selector(togglePin:)];
    self.removeButton = [self buttonWithFrame:NSMakeRect(282, 12, 242, 30) title:@"移除当前项目" action:@selector(removeSelectedProject:)];
    [self styleSecondaryButton:chooseButton];
    [self styleSecondaryButton:self.revealButton];
    [self styleSecondaryButton:self.pinButton];
    [self styleSecondaryButton:self.removeButton];

    NSView *commandCard = [self cardViewWithFrame:NSMakeRect(24, 84, 542, 96)
                                   backgroundColor:[self panelFillColor]
                                        borderColor:[self panelBorderColor]
                                       cornerRadius:22.0];
    NSTextField *commandsLabel = [self labelWithFrame:NSMakeRect(18, 58, 180, 20) text:@"启动命令" font:[NSFont systemFontOfSize:13 weight:NSFontWeightBold]];
    commandsLabel.textColor = [NSColor colorWithSRGBRed:0.17 green:0.21 blue:0.27 alpha:1.0];
    NSTextField *commandsHint = [self labelWithFrame:NSMakeRect(100, 58, 320, 18) text:@"固定命令在下拉里，自定义命令直接输入。" font:[NSFont systemFontOfSize:12]];
    commandsHint.textColor = NSColor.secondaryLabelColor;

    self.commandComboBox = [[NSComboBox alloc] initWithFrame:NSMakeRect(18, 18, 382, 34)];
    self.commandComboBox.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.commandComboBox.usesDataSource = NO;
    self.commandComboBox.completes = YES;
    self.commandComboBox.numberOfVisibleItems = 8;
    self.commandComboBox.placeholderString = @"选择或输入启动命令";
    [self styleInputControl:self.commandComboBox];

    self.launchButton = [self buttonWithFrame:NSMakeRect(412, 18, 112, 34) title:@"启动" action:@selector(launchSelectedCommand:)];
    [self stylePrimaryButton:self.launchButton];

    NSView *statusCard = [self cardViewWithFrame:NSMakeRect(24, 28, 542, 36)
                                  backgroundColor:[[NSColor whiteColor] colorWithAlphaComponent:0.66]
                                       borderColor:[[self panelBorderColor] colorWithAlphaComponent:0.9]
                                      cornerRadius:18.0];
    self.statusLabel = [self labelWithFrame:NSMakeRect(16, 9, 510, 18) text:@"" font:[NSFont systemFontOfSize:12 weight:NSFontWeightMedium]];
    self.statusLabel.textColor = NSColor.secondaryLabelColor;
    self.statusLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    [heroCard addSubview:badgeLabel];
    [heroCard addSubview:titleLabel];
    [heroCard addSubview:subtitleLabel];
    [heroCard addSubview:heroHint];

    [projectCard addSubview:projectLabel];
    [projectCard addSubview:projectHint];
    [projectCard addSubview:self.projectPopup];
    [projectCard addSubview:chooseButton];
    [projectCard addSubview:self.revealButton];
    [projectCard addSubview:self.pinButton];
    [projectCard addSubview:self.removeButton];

    [commandCard addSubview:commandsLabel];
    [commandCard addSubview:commandsHint];
    [commandCard addSubview:self.commandComboBox];
    [commandCard addSubview:self.launchButton];

    [statusCard addSubview:self.statusLabel];

    [contentView addSubview:glowLarge];
    [contentView addSubview:glowSmall];
    [contentView addSubview:heroCard];
    [contentView addSubview:projectCard];
    [contentView addSubview:commandCard];
    [contentView addSubview:statusCard];

    [self refreshCommandChoices];
}

- (void)refreshProjectMenuPreferSelection:(NSString *)preferredSelection {
    [self.projectPopup removeAllItems];
    NSArray<NSString *> *projects = [self allProjects];

    if (projects.count == 0) {
        [self.projectPopup addItemWithTitle:@"还没有保存过项目目录"];
        self.projectPopup.lastItem.enabled = NO;
        self.selectedProject = nil;
        [self updateControls];
        return;
    }

    for (NSString *project in projects) {
        NSString *title = [self projectMenuTitleForPath:project];
        [self.projectPopup addItemWithTitle:title];
        self.projectPopup.lastItem.representedObject = project;
        self.projectPopup.lastItem.toolTip = project;
    }

    NSString *targetProject = preferredSelection ?: self.selectedProject ?: projects.firstObject;
    NSInteger index = [projects indexOfObject:targetProject];
    if (index != NSNotFound) {
        [self.projectPopup selectItemAtIndex:index];
        self.selectedProject = targetProject;
    } else {
        [self.projectPopup selectItemAtIndex:0];
        self.selectedProject = projects.firstObject;
    }

    [self updateControls];
}

- (void)updateControls {
    BOOL hasProject = self.selectedProject.length > 0;
    self.pinButton.enabled = hasProject;
    self.removeButton.enabled = hasProject;
    self.revealButton.enabled = hasProject;
    self.launchButton.enabled = hasProject;

    if (hasProject) {
        BOOL isPinned = [self.pinnedProjects containsObject:self.selectedProject];
        self.pinButton.title = isPinned ? @"取消收藏当前项目" : @"收藏当前项目";
        self.statusLabel.stringValue = self.selectedProject;
    } else {
        self.pinButton.title = @"收藏当前项目";
        self.statusLabel.stringValue = @"先选一个项目目录。你也可以直接点“选择文件夹...”。";
    }
}

- (void)addRecentProject:(NSString *)path {
    [self.recentProjects removeObject:path];
    [self.recentProjects insertObject:path atIndex:0];
    while (self.recentProjects.count > 20) {
        [self.recentProjects removeLastObject];
    }
    [self saveConfig];
}

- (void)addRootFolder:(NSString *)path {
    [self.rootFolders removeObject:path];
    [self.rootFolders insertObject:path atIndex:0];
    [self saveConfig];
}

- (NSString *)currentCommandValue {
    return [self normalizedCommand:self.commandComboBox.stringValue fallback:@"codex"];
}

- (void)persistCurrentCommand {
    NSString *command = [self currentCommandValue];
    self.lastCommand = command;

    if (![[self defaultCommandChoices] containsObject:command]) {
        [self.customCommands removeObject:command];
        [self.customCommands insertObject:command atIndex:0];
        while (self.customCommands.count > 10) {
            [self.customCommands removeLastObject];
        }
    }

    [self refreshCommandChoices];
    [self saveConfig];
}

- (void)removeSelectedProject:(id)sender {
    if (self.selectedProject.length == 0) {
        self.statusLabel.stringValue = @"先选一个项目目录。";
        return;
    }

    NSString *projectToRemove = self.selectedProject;
    NSString *rootPath = [self rootFolderContainingProject:projectToRemove];
    BOOL removesRootFolder = (rootPath != nil);

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"确认移除";
    if (removesRootFolder) {
        alert.informativeText = [NSString stringWithFormat:@"当前目录来自父目录“%@”的子文件夹列表。移除后，这个父目录下面的所有子文件夹都会从列表里消失。", [self displayNameForPath:rootPath]];
    } else {
        alert.informativeText = [NSString stringWithFormat:@"移除“%@”后，它会从最近使用和收藏列表里删除。", [self displayNameForPath:projectToRemove]];
    }
    [alert addButtonWithTitle:@"移除"];
    [alert addButtonWithTitle:@"取消"];

    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    if (removesRootFolder) {
        [self.rootFolders removeObject:rootPath];
    }
    [self.recentProjects removeObject:projectToRemove];
    [self.pinnedProjects removeObject:projectToRemove];
    [self saveConfig];

    NSArray<NSString *> *projectsAfterRemoval = [self allProjects];
    NSString *nextSelection = projectsAfterRemoval.firstObject;
    self.selectedProject = nextSelection;
    [self refreshProjectMenuPreferSelection:nextSelection];

    if (removesRootFolder) {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"已移除父目录 %@ 及其子文件夹列表。", [self displayNameForPath:rootPath]];
    } else {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"已移除 %@。", [self displayNameForPath:projectToRemove]];
    }
}

- (NSString *)shellQuoted:(NSString *)value {
    NSString *escaped = [value stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    return [NSString stringWithFormat:@"'%@'", escaped];
}

- (NSString *)appleScriptEscaped:(NSString *)value {
    NSString *escaped = [value stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    return [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
}

- (void)launchSelectedCommand:(id)sender {
    if (self.selectedProject.length == 0) {
        self.statusLabel.stringValue = @"先选一个项目目录。";
        return;
    }

    [self persistCurrentCommand];

    NSString *command = [self currentCommandValue];
    NSString *shellCommand = [NSString stringWithFormat:@"cd %@ && %@", [self shellQuoted:self.selectedProject], command];
    NSString *escaped = [self appleScriptEscaped:shellCommand];
    NSArray<NSString *> *scriptLines = @[
        @"tell application \"Terminal\"",
        @"activate",
        [NSString stringWithFormat:@"do script \"%@\"", escaped],
        @"end tell",
    ];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/osascript";
    NSMutableArray<NSString *> *arguments = [NSMutableArray array];
    for (NSString *line in scriptLines) {
        [arguments addObject:@"-e"];
        [arguments addObject:line];
    }
    task.arguments = arguments;

    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"启动失败：%@", exception.reason ?: @"未知错误"];
        return;
    }

    if (task.terminationStatus != 0) {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Terminal 启动失败，退出码 %d。", task.terminationStatus];
        return;
    }

    [self addRecentProject:self.selectedProject];
    [self refreshProjectMenuPreferSelection:self.selectedProject];
    self.statusLabel.stringValue = [NSString stringWithFormat:@"已在 %@ 中启动 `%@`。", [self displayNameForPath:self.selectedProject], command];
}

- (void)chooseFolder:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = NO;
    panel.allowsMultipleSelection = NO;
    panel.canCreateDirectories = NO;
    panel.prompt = @"选择项目目录";
    panel.message = @"选一个目录。你可以只添加当前目录，也可以把它下面的子文件夹一起列出来。";

    if ([panel runModal] == NSModalResponseOK && panel.URL != nil) {
        NSString *selectedPath = panel.URL.path;
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"导入方式";
        alert.informativeText = @"要只添加当前文件夹，还是把这个文件夹下面的子文件夹都列出来？";
        [alert addButtonWithTitle:@"列出所有子文件夹"];
        [alert addButtonWithTitle:@"只添加当前文件夹"];
        [alert addButtonWithTitle:@"取消"];

        NSModalResponse response = [alert runModal];
        if (response == NSAlertThirdButtonReturn) {
            return;
        }

        if (response == NSAlertFirstButtonReturn) {
            NSArray<NSString *> *subdirectories = [self subdirectoriesForRoot:selectedPath];
            [self addRootFolder:selectedPath];
            if (subdirectories.count > 0) {
                self.selectedProject = subdirectories.firstObject;
                [self refreshProjectMenuPreferSelection:self.selectedProject];
                self.statusLabel.stringValue = [NSString stringWithFormat:@"已从 %@ 列出 %lu 个子文件夹。", [self displayNameForPath:selectedPath], (unsigned long)subdirectories.count];
            } else {
                self.selectedProject = selectedPath;
                [self addRecentProject:selectedPath];
                [self refreshProjectMenuPreferSelection:self.selectedProject];
                self.statusLabel.stringValue = @"这个目录下面没有可用的子文件夹，已改为添加当前目录。";
            }
            return;
        }

        self.selectedProject = selectedPath;
        [self addRecentProject:self.selectedProject];
        [self refreshProjectMenuPreferSelection:self.selectedProject];
    }
}

- (void)revealInFinder:(id)sender {
    if (self.selectedProject.length == 0) {
        return;
    }
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:self.selectedProject]]];
}

- (void)togglePin:(id)sender {
    if (self.selectedProject.length == 0) {
        return;
    }

    if ([self.pinnedProjects containsObject:self.selectedProject]) {
        [self.pinnedProjects removeObject:self.selectedProject];
        self.statusLabel.stringValue = [NSString stringWithFormat:@"已取消收藏 %@。", [self displayNameForPath:self.selectedProject]];
    } else {
        [self.pinnedProjects removeObject:self.selectedProject];
        [self.pinnedProjects insertObject:self.selectedProject atIndex:0];
        self.statusLabel.stringValue = [NSString stringWithFormat:@"已收藏 %@。", [self displayNameForPath:self.selectedProject]];
    }

    [self saveConfig];
    [self refreshProjectMenuPreferSelection:self.selectedProject];
}

- (void)projectSelectionChanged:(id)sender {
    NSMenuItem *item = self.projectPopup.selectedItem;
    if ([item.representedObject isKindOfClass:[NSString class]]) {
        self.selectedProject = (NSString *)item.representedObject;
    } else {
        self.selectedProject = nil;
    }
    [self updateControls];
}

- (void)windowWillClose:(NSNotification *)notification {
    if (notification.object == self.window) {
        [self persistCurrentCommand];
        [NSApp terminate:nil];
    }
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        LauncherAppDelegate *delegate = [[LauncherAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
