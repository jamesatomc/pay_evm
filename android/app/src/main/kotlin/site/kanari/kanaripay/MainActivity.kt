package site.kanari.kanaripay

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)

		// Prevent screenshots and screen recording for this activity
		// This sets the FLAG_SECURE window flag which tells the system
		// to treat the content of the window as secure, preventing it from
		// appearing in screenshots or on non-secure displays.
		window?.setFlags(
			WindowManager.LayoutParams.FLAG_SECURE,
			WindowManager.LayoutParams.FLAG_SECURE
		)
	}
}
