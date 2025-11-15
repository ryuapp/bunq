console.log("=== QuickJS-NG Demo ===");
console.log();

// Basic operations
console.log("Basic arithmetic:");
console.log("2 + 3 =", 2 + 3);
console.log("10 * 5 =", 10 * 5);
console.log();

// String operations
console.log("String operations:");
const name = "QuickJS";
const version = "ng";
console.log(`${name}-${version} from Zig`);
console.log();

// Array operations
console.log("Array operations:");
const numbers = [1, 2, 3, 4, 5];
console.log("Array:", numbers);
console.log("Sum:", numbers.reduce((a, b) => a + b, 0));
console.log("Doubled:", numbers.map((n) => n * 2));
console.log();

// Object operations
console.log("Object operations:");
const obj = {
  name: "Test",
  value: 42,
  method: function () {
    return this.value * 2;
  },
};
console.log("Object:", JSON.stringify(obj));
console.log("Method result:", obj.method());
console.log();

// Functions
console.log("Functions:");
function factorial(n) {
  return n <= 1 ? 1 : n * factorial(n - 1);
}
console.log("5! =", factorial(5));
console.log();

console.log("=== Demo Complete ===");
