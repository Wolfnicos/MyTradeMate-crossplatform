# TensorFlow Lite - Keep all TFLite classes
-keep class org.tensorflow.** { *; }
-keep interface org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }

# Keep GPU delegate classes
-keep class org.tensorflow.lite.gpu.** { *; }
-keepclassmembers class org.tensorflow.lite.gpu.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep TFLite operators
-keep class org.tensorflow.lite.Interpreter { *; }
-keep class org.tensorflow.lite.InterpreterApi { *; }
-keep class org.tensorflow.lite.Tensor { *; }

# Flutter tflite_flutter plugin
-keep class org.tensorflow.lite.flutter.** { *; }
