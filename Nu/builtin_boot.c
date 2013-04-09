install_builtin(@"boot", @"debug-mode", @"1");
install_builtin(@"boot", @"icloud-kvs-path", @"(path-in-docs \"notes\")");
install_builtin(@"boot", @"app", @"(UIApplication sharedApplication)");
install_builtin(@"boot", @"app-delegate", @"(app delegate)");
install_builtin(@"boot", @"window", @"(app-delegate window)");
install_builtin(@"boot", @"icloud-kvs", @"(app-delegate kvStore)");
