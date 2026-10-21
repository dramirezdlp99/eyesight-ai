# Reglas de R8 para la versión de producción de EyeSight AI.

# LiteRT (TensorFlow Lite): el intérprete se usa por FFI y JNI.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# El motor de Flutter hace referencia opcional a Play Core (componentes
# diferidos), que esta app no usa.
-dontwarn com.google.android.play.core.**
