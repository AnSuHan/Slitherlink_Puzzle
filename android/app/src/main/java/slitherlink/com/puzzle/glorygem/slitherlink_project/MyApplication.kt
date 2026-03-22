// android/app/src/main/java/slitherlink/com/puzzle/glorygem/slitherlink_project/MyApplication.kt
package slitherlink.com.puzzle.glorygem.slitherlink_project

import android.app.Application
import android.content.Context
import androidx.multidex.MultiDex
import androidx.multidex.MultiDexApplication

class MyApplication : MultiDexApplication() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        MultiDex.install(this)
    }
}