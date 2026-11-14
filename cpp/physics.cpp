#include <cmath>
#include <emscripten/emscripten.h>

// Deterministic football-ball integration helper for the optional WebAssembly build.
// The browser engine has a JavaScript fallback when this module is not loaded.
extern "C" {
EMSCRIPTEN_KEEPALIVE
void efootdls_step_ball(float* state, float dt, float gravity, float drag) {
    if (!state || dt <= 0.0f) return;
    state[0] += state[3] * dt;
    state[1] += state[4] * dt;
    state[2] += state[5] * dt;
    state[4] -= gravity * dt;
    const float damping = std::pow(drag, dt * 60.0f);
    state[3] *= damping;
    state[5] *= damping;
    if (state[1] < 0.48f) {
        state[1] = 0.48f;
        if (state[4] < 0.0f) state[4] = -state[4] * 0.42f;
    }
}
}
