#!/bin/bash

# Assets.xcassetsのパス
ASSETS_PATH="/Users/kaya.matsumoto/ios_watchme_v9/ios_watchme_v9/Assets.xcassets"

# BorderMedium - グレー50%
cat > "${ASSETS_PATH}/BorderMedium.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "0.500",
          "blue" : "0.500",
          "green" : "0.500",
          "red" : "0.500"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# ChartBackgroundColor - systemGray6
cat > "${ASSETS_PATH}/ChartBackgroundColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "systemGray6Color"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# InfoColor - blue
cat > "${ASSETS_PATH}/InfoColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "systemBlueColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# PlaceholderText - placeholderText
cat > "${ASSETS_PATH}/PlaceholderText.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "placeholderTextColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# PrimaryBackground - systemBackground
cat > "${ASSETS_PATH}/PrimaryBackground.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "systemBackgroundColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# PrimaryText - label
cat > "${ASSETS_PATH}/PrimaryText.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "labelColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# RecordingInactive - gray
cat > "${ASSETS_PATH}/RecordingInactive.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "systemGrayColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# ScoreNegativeColor - purple
cat > "${ASSETS_PATH}/ScoreNegativeColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "systemPurpleColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# ScorePositiveColor - green
cat > "${ASSETS_PATH}/ScorePositiveColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "systemGreenColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# ScoreVeryNegativeColor - red
cat > "${ASSETS_PATH}/ScoreVeryNegativeColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "systemRedColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# SecondaryActionColor - gray
cat > "${ASSETS_PATH}/SecondaryActionColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "systemGrayColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# SecondaryBackground - secondarySystemBackground
cat > "${ASSETS_PATH}/SecondaryBackground.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "secondarySystemBackgroundColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# SecondaryText - secondaryLabel
cat > "${ASSETS_PATH}/SecondaryText.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "secondaryLabelColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# SeparatorColor - グレー30%
cat > "${ASSETS_PATH}/SeparatorColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "0.300",
          "blue" : "0.500",
          "green" : "0.500",
          "red" : "0.500"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# TertiaryBackground - tertiarySystemBackground
cat > "${ASSETS_PATH}/TertiaryBackground.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "tertiarySystemBackgroundColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# TertiaryText - tertiaryLabel
cat > "${ASSETS_PATH}/TertiaryText.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "tertiaryLabelColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# TimelineActive - cyan
cat > "${ASSETS_PATH}/TimelineActive.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "platform" : "ios",
        "reference" : "systemCyanColor"
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# ZeroLineColor - グレー50%
cat > "${ASSETS_PATH}/ZeroLineColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "0.500",
          "blue" : "0.500",
          "green" : "0.500",
          "red" : "0.500"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ 18個のカラーセットを作成しました"
