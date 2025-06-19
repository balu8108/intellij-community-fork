// Copyright 2000-2025 JetBrains s.r.o. and contributors. Use of this source code is governed by the Apache 2.0 license.
import org.junit.Test;

public class JavaInfoTest {
    @Test
    public void printJavaInfo() {
        System.out.println("Java Version: " + System.getProperty("java.version"));
        System.out.println("Java Home: " + System.getProperty("java.home"));
    }
}

//bazel test :JavaInfoTest --test_output=all