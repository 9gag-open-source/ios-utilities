/*
Copyright 2017 Fueled Digital Media, LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
import Foundation
import ReactiveCocoa
import ReactiveSwift
import Result

public extension Signal {
	/**
	The original purpose of this method is to allow triggering animations in response to signal values.
	- Returns: a signal of which observers will receive values in the context defined by `context` function.
	- Parameters:
		- context: defines a context in which observers of the resulting signal will be called.
	## Example
	The following code
		self.constraint.reactive.constant <~ viewModel.constraintConstantValue.signal.observe(context: animatingContext)
	will result in all changes to `constraintConstantValue` in `viewModel` to be reflected in the constraint and animated.
	*/
	public func observe(context: @escaping (@escaping () -> Void) -> Void) -> Signal<Value, Error> {
		return Signal { observer in
			return self.observe { event in
				switch event {
				case .value:
					context({ observer.action(event) })
				default:
					observer.action(event)
				}
			}
		}
	}
}

/// Use with `observe(context:)` function to animate all changes made by observers of the signal returned from `observe(context:)`.
public func animatingContext(
	_ duration: TimeInterval,
	delay: TimeInterval = 0,
	options: UIViewAnimationOptions = [],
	layoutView: UIView? = nil,
	completion: ((Bool) -> Void)? = nil)
	-> ((@escaping () -> Void) -> Void)
{
	return { [weak layoutView] animations in
		layoutView?.layoutIfNeeded()
		UIView.animate(
			withDuration: duration,
			delay: delay,
			options: options,
			animations: {
				animations()
				layoutView?.layoutIfNeeded()
			},
			completion: completion)
	}
}

public extension SignalProducer {
	public func ignoreError() -> SignalProducer<Value, NoError> {
		return self.flatMapError { _ in
			SignalProducer<Value, NoError>.empty
		}
	}
	public func delayStart(_ interval: TimeInterval, on scheduler: DateScheduler) -> ReactiveSwift.SignalProducer<Value, Error> {
		return SignalProducer<(), Error>(value: ())
			.delay(interval, on: scheduler)
			.flatMap(.latest) { _ in self.producer }
	}
	public func observe(context: @escaping (@escaping () -> Void) -> Void) -> SignalProducer<Value, Error> {
		return lift { $0.observe(context: context) }
	}
}

public extension SignalProducer where Error == NoError {

	public func chain<U>(_ transform: @escaping (Value) -> Signal<U, NoError>) -> SignalProducer<U, NoError> {
		return flatMap(.latest, transform)
	}

	public func chain<U>(_ transform: @escaping (Value) -> SignalProducer<U, NoError>) -> SignalProducer<U, NoError> {
		return flatMap(.latest, transform)
	}

	public func chain<P: PropertyProtocol>(_ transform: @escaping (Value) -> P) -> SignalProducer<P.Value, NoError> {
		return flatMap(.latest) { transform($0).producer }
	}

	public func chain<U>(_ transform: @escaping (Value) -> Signal<U, NoError>?) -> SignalProducer<U, NoError> {
		return flatMap(.latest) { transform($0) ?? Signal<U, NoError>.never }
	}

	public func chain<U>(_ transform: @escaping (Value) -> SignalProducer<U, NoError>?) -> SignalProducer<U, NoError> {
		return flatMap(.latest) { transform($0) ?? SignalProducer<U, NoError>.empty }
	}

	public func chain<P: PropertyProtocol>(_ transform: @escaping (Value) -> P?) -> SignalProducer<P.Value, NoError> {
		return flatMap(.latest) { transform($0)?.producer ?? SignalProducer<P.Value, NoError>.empty }
	}

}

public extension PropertyProtocol {

	public func chain<U>(_ transform: @escaping (Value) -> Signal<U, NoError>) -> SignalProducer<U, NoError> {
		return producer.chain(transform)
	}

	public func chain<U>(_ transform: @escaping (Value) -> SignalProducer<U, NoError>) -> SignalProducer<U, NoError> {
		return producer.chain(transform)
	}

	public func chain<P: PropertyProtocol>(_ transform: @escaping (Value) -> P) -> SignalProducer<P.Value, NoError> {
		return producer.chain(transform)
	}

	public func chain<U>(_ transform: @escaping (Value) -> Signal<U, NoError>?) -> SignalProducer<U, NoError> {
		return producer.chain(transform)
	}

	public func chain<U>(_ transform: @escaping (Value) -> SignalProducer<U, NoError>?) -> SignalProducer<U, NoError> {
		return producer.chain(transform)
	}

	public func chain<P: PropertyProtocol>(_ transform: @escaping (Value) -> P?) -> SignalProducer<P.Value, NoError> {
		return producer.chain(transform)
	}

}

infix operator <~> : AssignmentPrecedence

@discardableResult public func <~> <P1: MutablePropertyProtocol, P2: MutablePropertyProtocol>(property1: P1, property2: P2) -> Disposable where P1.Value == P2.Value {
	let disposable = CompositeDisposable()
	var inObservation = false
	disposable += property2.producer.start {
		[weak property1] event in
		switch event {
		case let .value(value):
			if !inObservation {
				inObservation = true
				property1?.value = value
				inObservation = false
			}
		case .completed:
			disposable.dispose()
		default:
			break
		}
	}
	disposable += property1.producer.start {
		[weak property2] event in
		switch event {
		case let .value(value):
			if !inObservation {
				inObservation = true
				property2?.value = value
				inObservation = false
			}
		case .completed:
			disposable.dispose()
		default:
			break
		}
	}
	return disposable
}

extension Reactive where Base: NSLayoutConstraint {
	public var isActive: BindingTarget<Bool> {
		return makeBindingTarget { $0.isActive = $1 }
	}
}

extension Reactive where Base: UILabel {
	public var textAlignment: BindingTarget<NSTextAlignment> {
		return makeBindingTarget { $0.textAlignment = $1 }
	}
}

extension Reactive where Base: UIViewController {
	public var title: BindingTarget<String?> {
		return makeBindingTarget { $0.title = $1 }
	}
	public var performSegue: BindingTarget<(String, Any?)> {
		return makeBindingTarget { $0.performSegue(withIdentifier: $1.0, sender: $1.1) }
	}
}

extension Reactive where Base: UINavigationItem {
	public func hidesBackButton(animated: Bool) -> BindingTarget<Bool> {
		return makeBindingTarget { $0.setHidesBackButton($1, animated: animated) }
	}
	public func rightBarButtonItem(animated: Bool) -> BindingTarget<UIBarButtonItem?> {
		return makeBindingTarget { $0.setRightBarButton($1, animated: animated) }
	}
	public func rightBarButtonItems(animated: Bool) -> BindingTarget<[UIBarButtonItem]> {
		return makeBindingTarget { $0.setRightBarButtonItems($1, animated: animated) }
	}
	public func leftBarButtonItem(animated: Bool) -> BindingTarget<UIBarButtonItem?> {
		return makeBindingTarget { $0.setLeftBarButton($1, animated: animated) }
	}
	public func leftBarButtonItems(animated: Bool) -> BindingTarget<[UIBarButtonItem]> {
		return makeBindingTarget { $0.setLeftBarButtonItems($1, animated: animated) }
	}
	public var rightBarButtonItem: BindingTarget<UIBarButtonItem?> {
		return makeBindingTarget { $0.rightBarButtonItem = $1 }
	}
	public var rightBarButtonItems: BindingTarget<[UIBarButtonItem]> {
		return makeBindingTarget { $0.rightBarButtonItems = $1 }
	}
	public var leftBarButtonItem: BindingTarget<UIBarButtonItem?> {
		return makeBindingTarget { $0.leftBarButtonItem = $1 }
	}
	public var leftBarButtonItems: BindingTarget<[UIBarButtonItem]> {
		return makeBindingTarget { $0.leftBarButtonItems = $1 }
	}
}
