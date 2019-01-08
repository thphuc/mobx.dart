part of '../core.dart';

class Observable<T> extends Atom implements Interceptable<T>, Listenable<T> {
  /// Create an observable value with an [initialValue] and an optional [name]
  ///
  /// Observable values are tracked inside MobX. When a reaction uses them
  /// they are implicitly added as a dependency of the reaction. When its value changes
  /// the linked reaction is re-triggered.
  ///
  /// An observable's value is read with the `value` property.
  ///
  /// ```
  /// var x = observable(10);
  /// var message = observable('hello');
  ///
  /// print('x = ${x.value}'); // read an observable's value
  /// ```
  factory Observable(T initialValue, {String name, ReactiveContext context}) =>
      Observable._(context ?? currentContext, initialValue, name: name);

  Observable._(ReactiveContext context, this._value, {String name})
      : _interceptors = Interceptors(context),
        _listeners = Listeners(context),
        super._(context, name: name ?? context.nameFor('Observable'));

  final Interceptors<T> _interceptors;
  final Listeners<T> _listeners;

  T _value;

  T get value {
    reportObserved();
    return _value;
  }

  set value(T value) {
    final oldValue = _value;
    final newValue = _prepareNewValue(value);

    if (newValue == WillChangeNotification.unchanged) {
      return;
    }

    _value = newValue;

    reportChanged();

    if (_listeners.hasListeners) {
      final change = ChangeNotification<T>(
          newValue: value,
          oldValue: oldValue,
          type: OperationType.update,
          object: this);
      _listeners.notifyListeners(change);
    }
  }

  dynamic _prepareNewValue(T newValue) {
    var prepared = newValue;
    if (_interceptors.hasInterceptors) {
      final change = _interceptors.interceptChange(WillChangeNotification(
          newValue: prepared, type: OperationType.update, object: this));

      if (change == null) {
        return WillChangeNotification.unchanged;
      }

      prepared = change.newValue;
    }

    return (prepared != _value) ? prepared : WillChangeNotification.unchanged;
  }

  @override
  Dispose observe(Listener<T> listener, {bool fireImmediately}) {
    if (fireImmediately == true) {
      listener(ChangeNotification<T>(
          type: OperationType.update,
          newValue: _value,
          oldValue: null,
          object: this));
    }

    return _listeners.registerListener(listener);
  }

  @override
  Dispose intercept(Interceptor<T> interceptor) =>
      _interceptors.intercept(interceptor);
}
